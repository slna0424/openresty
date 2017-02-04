--20161219 by ln--
--订单列表--
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
	-- order_state_id
	if not request.post_fields.order_state_id or #request.post_fields.order_state_id == 0 then
		ngx.log(ngx.WARN, "merch_no empty, exit");
		ctx.code, ctx.msg = "XX",reason.order_state_empry;
		return false;
	end
	-- page_no
	if not request.post_fields.page_no or #request.post_fields.page_no == 0 then
		ngx.log(ngx.WARN, "page_no empty, exit");
		ctx.code, ctx.msg = "XX",reason.page_no_empty;
		return false;
	end	
	-- page_num
	if not request.post_fields.page_num or #request.post_fields.page_num == 0 then
		ngx.log(ngx.WARN, "page_num empty, exit");
		ctx.code, ctx.msg = "XX",reason.page_num_empty;
		return false;
	end
    return true;
end

-- response to terminal 
local function send_response(request, ctx, response)
	local rsp_msg,v_order_info = {},{};
    rsp_msg.term_no = request.post_fields.term_no or "";  -- Default empty.
    rsp_msg.merch_no = request.post_fields.merch_no or "";
    rsp_msg.code = ctx.code or "";
	local index = (response.msg and response.msg.v_order_info and #response.msg.v_order_info) or 0;
	for i = 1, index do
	    local tmp = {order_no = response.msg.v_order_info[i].order_sn,shop_id = response.msg.v_order_info[i].seller_id,
shop_name = response.msg.v_order_info[i].seller_name,retail_price = response.msg.v_order_info[i].money_order,trade_price = response.msg.v_order_info[i].money_order_trade};
		table.insert(v_order_info, tmp);
	end
	rsp_msg.v_order_info = v_order_info;
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
	send_msg.merch_no = request.post_fields.merch_no;
	send_msg.order_state = request.post_fields.order_state_id;
	send_msg.numPager = request.post_fields.page_no;
	send_msg.numItem = request.post_fields.page_num;
	if send_or_rcv_msg(path.order_list_url, send_msg, response) ~= true then
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
    ngx.log(ngx.INFO, "The final ctx: ",(cjson.encode(ctx)),"order_list, quit");
end


main();
