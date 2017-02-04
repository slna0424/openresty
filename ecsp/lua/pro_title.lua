--作者：宫丹
--创建时间: 2016-12-17
--描述：底部详情	

local cjson = require ("cjson.safe");
local common = require ("comm");
local reason = require("error_msg");
local path = require("path");
local comm_function = common.comm_function;
local pool_red = common.redis_connect;
local close_redis = common.redis_disconnect;

--校验请求报文
local function check_request(request, ctx)

	if not request.post_fields.term_no or #request.post_fields.term_no == 0 then
        ngx.log(ngx.WARN, "terminal empty, exit");
        ctx.code, ctx.msg = "XX",reason.term_no_empty;
		return false;
    end
	if not request.post_fields.merch_no or # request.post_fields.merch_no == 0 then
	    ngx.log(ngx.WARN, "merch_no empty, exit");
        ctx.code, ctx.msg = "XX",reason.merch_no_empty;
		return false;
	end
	return true;
end

--将信息返回给C端
local function send_response(request, ctx)
	local send_msg,v_title_info = {}, {};
	send_msg.term_no = request.post_fields.term_no or "";
	send_msg.merch_no = request.post_fields.merch_no or "";
	send_msg.img_path = path.local_pic_path;
	send_msg.code = ctx.code;
	send_msg.msg = ctx.msg;
	local title_id, err = request.red:smembers("title_id:");
	if title_id == nil then
		ngx.log(ngx.INFO, "term: ",request.post_fields.term_no, " title_info is empty");
		return false;
	end
	for i = 1, #title_id do
		local title_key = string.format("title:%s", title_id[i]);
		local title_info, err = request.red:hmget(title_key, "title_id", "title_name", "title_img", "htitle_img");
		if title_info == nil then
			ngx.log(ngx.INFO, "term: ",request.post_fields.term_no, " title_info is empty");
			return false;
		end
		local tmp = {title_id = title_info[1], title_name = title_info[2], bottom_select = title_info[3], bottom = title_info[4]};
	    table.insert(v_title_info, tmp);		
	end
	send_msg.v_title_info = v_title_info;
	local message = cjson.encode(send_msg);
	local res = string.gsub(message, "\\","");
	ngx.log(ngx.INFO, "term_no: ", request.post_fields.term_no, "  message:",res);
	ngx.print(res);
	ngx.eof();
	return true;
end

local function pro_title()
	local request, response, ctx = {}, {}, {};
	ctx.code, ctx.msg = "00", "";
	
	--接收C端请求报文
	if comm_function(request) ~= true then
		ngx.log(ngx.INFO, "term: ",request.post_fields.term_no, " rcv request msg failed");
		ctx.code, ctx.msg = "", reason.system_error;
		goto send;
	end 
	--校验请求报文
	if check_request(request, ctx) ~= true then
		ngx.log(ngx.INFO, "term: ",request.post_fields.term_no, " check_request failed");
		goto send;
	end
	--链接redis数据库
	if pool_red(request) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " connect redis failed");
		ctx.code, ctx.msg = "XX", reason.data_base_error;
		goto send;
	end
	--将信息返回给C端	
	::send:: do
		if send_response(request, ctx, response) ~= true then
            ngx.log(ngx.ERR, "send_response failed");
        end
	end
		
	--关闭redis数据库
	if close_redis(request) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " close redis failed");
	end
	return true;
end
pro_title()
