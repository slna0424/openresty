--作者：宫丹
--创建时间: 2016-12-05
--描述：商品详情
 
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
	    ngx.log(ngx.WARN, "merch empty, exit");
        ctx.code, ctx.msg = "XX",reason.merch_no_empty;
		return false;
	end
    if not request.post_fields.pro_sku or #request.post_fields.pro_sku == 0 then
        ngx.log(ngx.WARN, "sku_no empty, exit");
        ctx.code, ctx.msg = "XX",reason.sku_no_empty;
		return false;
    end	
	return true;
end

--发送、接收电商平台响应
local function request_pro_info(request, ctx, response) 
	local send_msg = {};
	send_msg.merch_no = request.post_fields.merch_no or "";         --商户编号
	send_msg.sku = request.post_fields.pro_sku or "";               --sku号
	if send_or_rcv_msg(path.pro_info_url, send_msg, response) ~= true then
		ngx.log(ngx.INFO, "term: ",request.post_fields.term_no, " send_or_rcv_msg failed");
		code, msg = "", reason.system_error;
		return false;	
	end
	--判断返回信息是否成功
	local status = (response.msg and response.msg.status) or "";
	if "0" ~= status then
		ctx.code, ctx.msg = "XX", response.msg.message;
		return false;
	end
	return true;
end

--返回给终端响应报文
local function send_response(request, ctx, response)
	local send_msg = {};
	send_msg.term_no = (request.post_fields and request.post_fields.term_no) or "";           --终端编号
	send_msg.merch_no = (request.post_fields and request.post_fields.merch_no) or "";         --商户编号
	send_msg.code = ctx.code;                                                                 --错误码
	send_msg.msg = ctx.msg;                                                                   --错误信息
	send_msg.pro_price = (response.msg and response.msg.mall_casm_price) or "";               --商品价格
	send_msg.total_num = (response.msg and response.msg.product_stock) or "";                 --库存量
	local message = cjson.encode(send_msg);
	ngx.log(ngx.INFO, "term_no: ", request.post_fields.term_no, "  message:",message);
	ngx.print(message);
	ngx.eof();
	return true;
end

local function pro_info_main()
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
	
	--发送、接收电商平台响应
	if request_pro_info(request, ctx, response) ~= true then
		ngx.log(ngx.INFO, "term: ",request.post_fields.term_no, " request_pro_info failed");
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
pro_info_main()
