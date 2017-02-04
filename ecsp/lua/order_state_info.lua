--20161219 by ln--
--订单状态下载--
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
	if not request.post_fields.merch_no or #request.post_fields.merch_no == 0 then
		ngx.log(ngx.WARN, "merch_no empty, exit");
		ctx.code, ctx.msg = "XX",reason.merch_no_empty;
		return false;
	end
    return true;
end

-- response to terminal 
local function send_response(request, ctx, response)
	local rsp_msg,v_order_state = {},{};
    rsp_msg.term_no = request.post_fields.term_no or "";  -- Default empty.
    rsp_msg.merch_no = request.post_fields.merch_no or "";
    rsp_msg.code = ctx.code or "";
	local index = (response.msg and response.msg.v_order_state and #response.msg.v_order_state) or 0;
	for i = 1, index do
	    local tmp = {order_state_id = response.msg.v_order_state[i].code_cd,order_state_name = response.msg.v_order_state[i].code_text};
		table.insert(v_order_state, tmp);
	end
	rsp_msg.v_order_state = v_order_state;
	rsp_msg.msg = ctx.msg;
    local message = cjson.encode(rsp_msg);
    ngx.print(message);
	ngx.log(ngx.INFO,"msg:",message);
    ngx.eof();
    return true;
end

--发送、接收电商平台响应
local function get_orderstate(request, ctx, response)
	local send_msg = {};
	if send_or_rcv_msg(path.order_state_url, send_msg, response) ~= true then
		ngx.log(ngx.INFO, "merch_no: ",request.post_fields.merch_no, " send_or_rcv_msg failed");
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
	if get_orderstate(request, ctx, response) ~= true then
		ngx.log(ngx.ERR, "get_orderstate failed.")
		goto send;
	end
    -- Begin of `Response'.
    ::send:: do
        if send_response(request, ctx, response) ~= true then
            ngx.log(ngx.ERR, "send_response failed"); 
        end
    end
    ngx.log(ngx.INFO, "The final ctx: ", (cjson.encode(ctx)),"order_state_info end, quit");
end


main();
