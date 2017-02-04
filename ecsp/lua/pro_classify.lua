--作者：宫丹
--创建时间: 2016-12-02
--描述：商品分类信息
 
local cjson = require ("cjson.safe");
local common = require ("comm");
local reason = require("error_msg");
local path = require("path");
local comm_function = common.comm_function;
local send_or_rcv_msg = common.send_or_rcv_msg;

--发送消息到电商平台
local function request_chanl_no_info(request, ctx, response)
	local send_msg = {};
	send_msg.merch_no = request.post_fields.merch_no or "";         --商户编号
	send_msg.cate_id = "-1";                                        --渠道编号
	send_msg.numPager = request.post_fields.page_no or "";          --页数
	send_msg.numItem = request.post_fields.page_num or "";          --个数

	if send_or_rcv_msg(path.gmenu_url, send_msg, response) ~= true then
		ngx.log(ngx.INFO, "term: ",request.post_fields.term_no, " send_or_rcv_msg failed");
		ctx.code, ctx.msg = "", reason.system_error;
		return false;
	end
	--判断返回信息是否成功
	ngx.log(ngx.INFO,"response.msg.status: ", response.msg.status, "response.msg.message: ", response.msg.message);
	if "0" ~= response.msg.status then
		ctx.code, ctx.msg = "XX", response.msg.message;
		return false;
	end
	return true;
end

--将消息返回给终端
local function send_response(request, ctx, response)
	local send_msg,v_calssify  = {}, {};
	local chanl_img, chanl_logo, logo = "", "", "";
	send_msg.term_no = request.post_fields.term_no or "";        --终端编号
	send_msg.merch_no = request.post_fields.merch_no or "";
	send_msg.code = ctx.code;
	send_msg.msg = ctx.msg;
	send_msg.img_path = path.local_pic_path .. "class_bg.png";
	if "0" == response.msg.status then
		local index = (response.msg and response.msg.v_cate_info and #response.msg.v_cate_info);
		for i = 1, index do
			local tmp = {cafy_id = response.msg.v_cate_info[i].id, cafy_name = response.msg.v_cate_info[i].name};
			table.insert(v_calssify, tmp);
		end
	end
	send_msg.v_calssify = v_calssify;
	local message = cjson.encode(send_msg);
	local res = string.gsub(message, "\\","");
	ngx.log(ngx.INFO, "term_no: ", request.post_fields.term_no, "  message:",res);
	ngx.print(res);
	ngx.eof();
	return true;
end

local function gmenu_main()
	
	local request, response, ctx = {},{},{};
	ctx.code, ctx.msg = "00", "";
	
	--接收C端请求报文
	if comm_function(request) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " rcv request msg failed");
		ctx.code, ctx.msg = "", reason.system_error;
		goto send;
	end

	--发送消息到电商平台
	if request_chanl_no_info(request, ctx, response) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " rcv request msg failed");
		goto send;
	end
	
	--发送返回报文
	::send:: do
		if send_response(request, ctx, response) ~= true then
            ngx.log(ngx.ERR, "send_response failed");
        end
	end
	return true;
end
gmenu_main()
