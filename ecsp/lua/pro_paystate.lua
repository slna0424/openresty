--20161205 by ln--
--支付状态更新--
local cjson = require("cjson.safe");
local reason = require("error_msg");
local common = require ("comm");
local path = require("path");
local comm_function = common.comm_function;
local send_or_rcv_msg = common.send_or_rcv_msg;
local pool_red = common.redis_connect;
local close_redis = common.redis_disconnect;

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
	-- card_no
	if not request.post_fields.card_no or #request.post_fields.card_no == 0 then
        ngx.log(ngx.WARN, "card_no empty, exit");
		ctx.code, ctx.msg = "XX",reason.card_no_empty;
		return false;
    end
	-- pwyid 支付方式id
	if not request.post_fields.pwyid or #request.post_fields.pwyid == 0 then
        ngx.log(ngx.WARN, "pwyid empty, exit");
		ctx.code, ctx.msg = "XX",reason.card_no_empty;
		return false;
    end
	-- pwyname 支付方式名称
	if not request.post_fields.pwyname or #request.post_fields.pwyname == 0 then
        ngx.log(ngx.WARN, "pwyname empty, exit");
		ctx.code, ctx.msg = "XX",reason.card_no_empty;
		return false;
    end
	-- pay_state
	if not request.post_fields.pay_state or #request.post_fields.pay_state == 0 then
		ngx.log(ngx.WARN, "pay_state empty, exit");
		ctx.code, ctx.msg = "XX",reason.pay_state_empty;
		return false;
	end
	--[[
	-- trans_no
	if not request.post_fields.trans_no or #request.post_fields.trans_no == 0 then
		ngx.log(ngx.WARN, "trans_no empty, exit");
		ctx.code, ctx.msg = "XX",reason.trans_params_empty;
		return false;
	end
	-- batch_no
	if not request.post_fields.batch_no or #request.post_fields.batch_no == 0 then
		ngx.log(ngx.WARN, "batch_no empty, exit");
		ctx.code, ctx.msg = "XX",reason.trans_params_empty;
		return false;
	end
	-- xtckh
	if not request.post_fields.xtckh or #request.post_fields.xtckh == 0 then
		ngx.log(ngx.WARN, "xtckh empty, exit");
		ctx.code, ctx.msg = "XX",reason.trans_params_empty;
		return false;
	end
	--]]
	if not request.post_fields.v_order_info or #request.post_fields.v_order_info == 0 then
		ngx.log(ngx.WARN, "v_order_info empty, exit");
		ctx.code, ctx.msg = "XX",reason.order_no_empty;
		return false;
	end
	for i=1, #request.post_fields.v_order_info do
		--pro_price
		if not request.post_fields.v_order_info[i].pro_price or #request.post_fields.v_order_info[i].pro_price == 0 then
			ngx.log(ngx.WARN, "pro_price empty, exit");
			ctx.code, ctx.msg = "XX",reason.price_empty;
			return false;
		end
		--order_no
		if not request.post_fields.v_order_info[i].order_no or #request.post_fields.v_order_info[i].order_no == 0 then
			ngx.log(ngx.WARN, "order_no empty, exit");
			ctx.code, ctx.msg = "XX",reason.order_no_empty;
			return false;
		end	
	end

    return true;
end
-- response to terminal 
local function send_response(request, ctx, response)
    local rsp_msg = {};
    rsp_msg.term_no = request.post_fields.term_no or "";  -- Default empty.
    rsp_msg.merch_no = request.post_fields.merch_no or "";
    rsp_msg.code = ctx.code or "";
    rsp_msg.msg = ctx.msg;
    local message = cjson.encode(rsp_msg);
    ngx.print(message);
	ngx.log(ngx.INFO,"msg:",message);
    ngx.eof();
    return true;
end


--发送、接收电商平台响应
local function put_paystate(request, ctx, response)
	local send_msg,v_order_info = {},{};
	send_msg.merch_no = request.post_fields.merch_no or "";
	send_msg.name = request.post_fields.card_no or "";
	send_msg.payment_code = request.post_fields.pwyid or "";
	send_msg.payment_name = request.post_fields.pwyname or "";
	--todo 去交易流水中去查
	send_msg.payment_status = request.post_fields.pay_state;   --1.成功，2.失败     		
	send_msg.pay_sn = "000000";           	--lsbh  todo
	local index = request.post_fields and request.post_fields.v_order_info and #request.post_fields.v_order_info or 0;
	for i = 1,index do
		local tmp = {order_sn = request.post_fields.v_order_info[i].order_no,money_order_trade = request.post_fields.v_order_info[i].pro_price};
		table.insert(v_order_info,tmp);
	end
	send_msg.v_order_info = v_order_info;
	if send_or_rcv_msg(path.pro_paystate_url, send_msg, response) ~= true then
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

local function update_logs(request)

	local status = request.post_fields.pay_state;
	for i=1, #request.post_fields.v_order_info do
		ngx.log(ngx.INFO,  "order_no: ",request.post_fields.v_order_info[i].order_no," status: ", status);
		local order_key = string.format("order:%s", request.post_fields.v_order_info[i].order_no);
		local ok, err = request.red:hset(order_key, "status",status);
		if ok == nil then
			ngx.log(ngx.INFO, "merch_no: ",request.post_fields.merch_no, "order_key is null");
			return false;
		end
		ngx.log(ngx.INFO, "order_key: ", order_key,"status:",status);
	end
	return true;
end

local function main()
    ngx.log(ngx.INFO, "now process request ...");
    -- Context & generic data.
    local request, ctx, response = {}, {}, {};
    ctx.code, ctx.msg = "00", "";
		--链接redis数据库
	if pool_red(request) ~= true then
		ngx.log(ngx.INFO, "merch_no: ",request.post_fields.merch_no, " connect redis failed");
		ctx.code, ctx.msg = "", reason.system_error;
		goto send;
	end
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
	if put_paystate(request, ctx, response) ~= true then
		ngx.log(ngx.ERR, "put_paystate failed.")
		goto send;
	end
    -- Begin of `Response'.
    ::send:: do
        if send_response(request, ctx, response) ~= true then
            ngx.log(ngx.ERR, "send_response failed");
			ctx.code,ctx.msg = "XX",reson.system_error;
        end

        ngx.log(ngx.INFO, "Send response: [", response.message, "]");
    end

	-- record logs
	if update_logs(request) ~= true then
		ngx.log(ngx.ERR, "update_logs failed.")
	end
	
	--关闭数据库
	if close_redis(request) ~= true then
		ngx.log(ngx.INFO, "merch_no: ",request.post_fields.merch_no, " close redis failed");
	end
    ngx.log(ngx.INFO, "The final ctx: ", (cjson.encode(ctx)),"pay_state end, quit");
end


main();
