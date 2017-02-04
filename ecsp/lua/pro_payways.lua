--20161205 by ln--
--结算前支付方式信息下载--

local cjson = require("cjson.safe");
local common = require ("comm");
local reason = require("error_msg");
local path = require("path");
local comm_function = common.comm_function;
local send_or_rcv_msg = common.send_or_rcv_msg;

local function check_request(request,ctx)
    -- terminal.
    if not request.post_fields.term_no or #request.post_fields.term_no == 0 then
        ngx.log(ngx.WARN, "terminal empty, exit");
		ctx.code, ctx.msg = "XX",reason.term_no_empty;
		return false;
    end 
	-- merch
	if not request.post_fields.merch_no or #request.post_fields.merch_no == 0 then
		ngx.log(ngx.WARN, "merch_no empty, exit");
		ctx.code, ctx.msg = "XX",reason.merch_no_empty;
		return false;
	end
	-- shop_id
    if not request.post_fields.v_shop_id or #request.post_fields.v_shop_id == 0 then
		ngx.log(ngx.WARN, "shop_id_empty, exit");
		ctx.code, ctx.msg = "XX",reason.shop_id_empty;
		return false;
    end
	for i=1, #request.post_fields.v_shop_id do
		if not request.post_fields.v_shop_id[i].shop_id or #request.post_fields.v_shop_id[i].shop_id == 0 then
			ngx.log(ngx.WARN, "shop_id_empty, exit");
			ctx.code, ctx.msg = "XX",reason.shop_id_empty;
			return false;
		end
	end
    return true;
end

-- response to terminal 
local function send_response(request, ctx, response)
	local rsp_msg,v_payway = {},{};
    rsp_msg.term_no = request.post_fields.term_no or "";  -- Default empty.
    rsp_msg.merch_no = request.post_fields.merch_no or "";
    rsp_msg.code = ctx.code or "";
	local index = (response.msg and response.msg.v_payway and #response.msg.v_payway) or 0;
	for i = 1, index do
	    local tmp = {pwyid = response.msg.v_payway[i].payment_code,pwyname = response.msg.v_payway[i].payment_name};
		table.insert(v_payway, tmp);
	end
	rsp_msg.v_payway = v_payway;
	rsp_msg.msg = ctx.msg;
    local message = cjson.encode(rsp_msg);
    ngx.print(message);
	ngx.log(ngx.INFO,"msg:",message);
    ngx.eof();
    return true;
end

--发送、接收电商平台响应
local function get_payways(request, ctx, response)
	local send_msg,v_shop_id = {},{};
	send_msg.merch_no = request.post_fields.merch_no or "";
	send_msg.chanl_no = "3";           								 --渠道：E终端3
	for i = 1, #request.post_fields.v_shop_id do
		ngx.log(ngx.INFO, "request.post_fields.v_shop_id: ", request.post_fields.v_shop_id[i].shop_id);
		local tmp = {shop_id = request.post_fields.v_shop_id[i].shop_id};
		table.insert(v_shop_id, tmp);	
	end
	send_msg.v_shop_id = v_shop_id;
	if send_or_rcv_msg(path.pro_payways_url, send_msg, response) ~= true then
		ngx.log(ngx.INFO, "merch_no: ",request.post_fields.merch_no, " send_or_rcv_msg failed");
		ctx.code, ctx.msg = "", reason.system_error;
		return false;
	end
	--判断返回信息是否成功
	ngx.log(ngx.INFO, "status: ", response.msg.status);
	ngx.log(ngx.INFO, "message: ", response.msg.message);
	local status = (response.msg and response.msg.status)
		ngx.log(ngx.INFO, "status: ", status);
		if "0" ~= status then
			ctx.code, ctx.msg = "XX", response.msg.message;
			return false;
		end
	return true;
end

local function main()
    ngx.log(ngx.INFO, "now process request ...");
    -- Context & generic data.
    local request, ctx, response = {}, {}, {};
    ctx.code, ctx.msg = "00", "";
	-- Begin of `Parse'.
    if comm_function(request) ~= true then
        ngx.log(ngx.ERR, "parse_request failed, sending response");
		ctx.code, ctx.msg = "", reason.system_error;
        goto send;
    end

    -- Request check.
    if check_request(request,ctx) ~= true then
		ngx.log(ngx.ERR, "check_request failed, sending response");
        goto send;
    end

	-- Order Generated to web
	if get_payways(request, ctx, response) ~= true then
		ngx.log(ngx.ERR, "get_payways failed.")
		goto send;
	end
    -- Begin of `Response'.
    ::send:: do
        if send_response(request, ctx, response) ~= true then
            ngx.log(ngx.ERR, "send_response failed");
        end
    end
    ngx.log(ngx.INFO, "The final ctx: ",cjson.encode(ctx),"payways end, quit");
end


main();
