--作者：宫丹
--创建时间: 2016-12-02
--描述：商品列表

local cjson = require ("cjson.safe");
local common = require ("comm");
local reason = require("error_msg");
local path = require("path");
local comm_function = common.comm_function;
local send_or_rcv_msg = common.send_or_rcv_msg;

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
    if not request.post_fields.cafy_id or #request.post_fields.cafy_id == 0 then
        ngx.log(ngx.WARN, "cafy_id empty, exit");
        ctx.code, ctx.msg = "XX",reason.cafy_id_empty;
		return false;
    end
	if not request.post_fields.page_no or #request.post_fields.page_no == 0 then
		ngx.log(ngx.WARN, "page_no empty, exit");
		ctx.code, ctx.msg = "XX",reason.page_no_empty;
		return false;
	end
	if not request.post_fields.page_num or #request.post_fields.page_num == 0 then
        ngx.log(ngx.WARN, "page_num empty, exit");
        ctx.code, ctx.msg = "XX",reason.page_num_empty;
		return false;
    end
	
	return true;
end

--发送、接收电商平台响应
local function request_pro_list_info(request, ctx, response)
	local send_msg = {};
	send_msg.merch_no = request.post_fields.merch_no or "";         --商户编号
	send_msg.cate_id = request.post_fields.cafy_id or "";           --渠道编号
	send_msg.numPager = request.post_fields.page_no or "";           --页数
	send_msg.numItem = request.post_fields.page_num or "";         --个数
	if send_or_rcv_msg(path.pro_list_url, send_msg, response) ~= true then
		ngx.log(ngx.INFO, "term: ",request.post_fields.term_no, " send_or_rcv_msg failed");
		ctx.code, ctx.msg = "", reason.system_error;
		return false;
	end	
	--判断返回信息是否成功
	local status = (response.msg and response.msg.status)
	ngx.log(ngx.INFO, "status: ", status);
	if "0" ~= status then
		ctx.code, ctx.msg = "XX", response.msg.message;
		return false;
	end
	return true;
end

--返回给终端响应报文
local function send_response(request, ctx, response)
	local send_msg,v_pro_spu  = {}, {};
	send_msg.term_no = request.post_fields.term_no or "";        --终端编号
	send_msg.merch_no = request.post_fields.merch_no or "";
	send_msg.file_path = path.file_path or "";                   --文件路径
	local pic_path = path.pic_path .. request.post_fields.cafy_id .. "/";
	send_msg.img_path = pic_path or "";                          --图片路径
	send_msg.code = ctx.code;
	send_msg.msg = ctx.msg;
	
	local index = (response.msg and response.msg.v_product_code and #response.msg.v_product_code) or 0;
	for i = 1, index do
	    local tmp = {pro_spu = response.msg.v_product_code[i].product_code};
		table.insert(v_pro_spu, tmp);
	end
	send_msg.v_pro_spu = v_pro_spu;
	local message = cjson.encode(send_msg);
	local res = string.gsub(message, "\\","");
	ngx.log(ngx.INFO, "term_no: ", request.post_fields.term_no, "  message:",res);
	ngx.print(res);
	ngx.eof();
	return true;
end

local function pro_list_main()
	local request,response, ctx = {}, {}, {};
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
	
	--发送、接收电商平台响应
	if request_pro_list_info(request, ctx, response) ~= true then
		ngx.log(ngx.INFO, "term: ",request.post_fields.term_no, " request_pro_list_info failed");
		goto send;	
	end

	--将信息返回给C端	
	::send:: do
		if send_response(request, ctx, response) ~= true then
            ngx.log(ngx.ERR, "send_response failed");
        end
	end
	return true;
end
pro_list_main()
