--作者：宫丹
--创建时间: 2016-12-19
--描述：首页	

local cjson = require ("cjson.safe");
local common = require ("comm");
local reason = require("error_msg");
local path = require("path");
local comm_function = common.comm_function;

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
	send_msg.main_img = path.local_pic_path .. "main_img.png";
	send_msg.adv_img = path.local_pic_path .. "adv1.png";
	send_msg.code = ctx.code;
	send_msg.msg = ctx.msg;
	local message = cjson.encode(send_msg);
	local res = string.gsub(message, "\\","");
	ngx.log(ngx.INFO, "term_no: ", request.post_fields.term_no, "  message:",res);
	ngx.print(res);
	ngx.eof();
	return true;
end

local function main_menu()
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
	--将信息返回给C端	
	::send:: do
		if send_response(request, ctx) ~= true then
            ngx.log(ngx.ERR, "send_response failed");
        end
	end
	return true;
end
main_menu()
