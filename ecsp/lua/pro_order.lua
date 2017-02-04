--20161205 by ln--
--客户下单--
local cjson = require("cjson.safe");
local common = require ("comm");
local reason = require("error_msg");
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
	-- v_pro_sku
	if not request.post_fields.v_pro_sku or #request.post_fields.v_pro_sku == 0 then
		ngx.log(ngx.WARN, "pro_sku empty, exit");
	    ctx.code, ctx.msg = "XX",reason.sku_no_empty;
		return false;
	end
	for i=1, #request.post_fields.v_pro_sku do
		if not request.post_fields.v_pro_sku[i].pro_sku or #request.post_fields.v_pro_sku[i].pro_sku == 0 then
			ngx.log(ngx.WARN, "pro_sku empty, exit");
			ctx.code, ctx.msg = "XX",reason.sku_no_empty;
			return false;
		end
		if not request.post_fields.v_pro_sku[i].num or request.post_fields.v_pro_sku[i].num == 0 then
			ngx.log(ngx.WARN, "num empty, exit");
			ctx.code, ctx.msg = "XX",reason.sku_num_empty;
			return false;
		end
	end
    return true;
end
-- response to terminal 
local function send_response(request, ctx, response)
    local send_msgs,v_pro_sku_lack = {},{};
	send_msgs.code = ctx.code or "";
	send_msgs.msg = ctx.msg or "";   
    send_msgs.term_no = (request.post_fields and request.post_fields.term_no) or "";    -- Default empty.
    send_msgs.merch_no = (request.post_fields and request.post_fields.merch_no) or "";
    send_msgs.order_no = (response.msg and response.msg.order_sn) or "";                --订单编号
    send_msgs.pro_price = (response.msg and response.msg.money_price) or "";            --（商品零售价总价-优惠金额）
    send_msgs.pro_logs =  (response.msg and response.msg.money_logistics) or "";        --邮费
	send_msgs.v_pro_sku = request.post_fields.v_pro_sku;
    --send_msgs.yhje = (response.msg and response.msg.money_coupon) or "";              --优惠券优惠金额
    --send_msgs.mjje = (response.msg and response.msg.money_act_full) or "";            --满减金额
    --send_msgs.yhzje = (response.msg and response.msg.money_discount) or "";           --优惠总金额

	local status = (response.msg and response.msg.status) or "";
	ngx.log(ngx.INFO, "status: ", status);

	if "103" == status then     --商品库存不足
		local index = (response.msg and #response.msg.v_store_info) or 0;
		for i = 1, index do
			local tmp = {pro_sku = response.msg.v_store_info[i].store_info};
			table.insert(v_pro_sku_lack, tmp);
		end	
		send_msgs.v_pro_sku_lack = v_pro_sku_lack;
		send_msgs.code = "XX";
		send_msgs.msg = ""; 
    end
	
	local send_message = cjson.encode(send_msgs);
    ngx.print(send_message);
	ngx.log(ngx.INFO,"msg:",send_message);
    ngx.eof();
    return true;
end
-- Order Generated to web
local function generated_order(request, ctx, response)
	local send_msg, v_pro_sku = {}, {};
	
	send_msg.merch_no = request.post_fields.merch_no or "";
	send_msg.order_type = "1";
	for i = 1, #request.post_fields.v_pro_sku do
	    ngx.log(ngx.INFO, "request.post_fields.v_pro_sku: ", request.post_fields.v_pro_sku[i].pro_sku,"num: ",request.post_fields.v_pro_sku[i].num);
		local tmp = {sku = request.post_fields.v_pro_sku[i].pro_sku, number = request.post_fields.v_pro_sku[i].num};
		table.insert(v_pro_sku, tmp);	
	end
	send_msg.order_info = v_pro_sku;
	if send_or_rcv_msg(path.pro_order_url, send_msg, response) ~= true then
		ngx.log(ngx.INFO, "merch_no: ",request.post_fields.merch_no, " send_or_rcv_msg failed");
		ctx.code, ctx.msg = "", reason.system_error;
		return false;
	end
	--判断返回信息是否成功
	if "0" ~= response.msg.status then
		ctx.code, ctx.msg = "XX", response.msg.message;
		return false;
	end
	return true;
end
-- record logs
local function record_logs(request,response)

	local money_discount = response.msg.money_discount or ""; --优惠总金额
	local money_product = response.msg.money_product or "";   --商品零售总价
	local money_order = response.msg.money_order or "";       --订单实际总金额（零售总价+运费-优惠）
	local money_price = response.msg.money_price or "";       --订单总金额（零售总价-优惠）
	local money_product_trade = response.msg.money_product_trade or "";    --商品批发总价
	local money_order_trade = response.msg.money_order_trade or "";        --订单实际总金额
	local money_price_trade = response.msg.money_price_trade or "";        --订单总金额
	local money_logistics = response.msg.money_logistics or "";            --物流费用
	local money_coupon = response.msg.money_coupon or "";                  --优惠券优惠金额
	local money_act_full = response.msg.money_act_full or "";              --满减金额
	local term_no = request.post_fields.term_no;
	local status = response.msg.status;
	local jszh = response.msg.settle_account or "";
	local get_date = ngx.today();
	ngx.log(ngx.INFO, " money_discount: ", money_discount, " money_product: ",money_product, " money_order: ",money_order," money_price: ",money_price," money_product_trade: ",money_product_trade," money_order_trade: ",money_order_trade," money_price_trade: ",money_price_trade," money_logistics: ", money_logistics, " money_coupon: ",money_coupon, " money_act_full: ",money_act_full," term_no: ", term_no, " status: ", status, " jszh: ",jszh," date: ",get_date);
	
	--优惠总金额、商品零售总价、订单实际总金额（零售总价+运费-优惠）、订单总金额（零售总价-优惠）、商品批发总价、订单实际总金额，订单总金额、物流费用、优惠券优惠金额、满减金额、终端编号、状态、结算账号、插入时间
	local order_key = string.format("order:%s", response.msg.order_sn);
	ngx.log(ngx.INFO, "order_key: ", order_key);
	
	local ok, err = request.red:hmset(order_key, "money_discount", money_discount, "money_product", money_product, "money_order",money_order,"money_price",money_price,"money_product_trade",money_product_trade,"money_order_trade",money_order_trade,"money_price_trade",money_price_trade,"money_logistics",money_logistics, "money_coupon", money_coupon, "money_act_full",money_act_full,"term_no",term_no, "status",status, "jszh",jszh,"date",get_date);
	if ok == nil then
		ngx.log(ngx.INFO, "hmset: ",order_key, " is error.");
		return false;
	end
	
	local ok,err = request.red:sadd("order_sum:",response.msg.order_sn)
	if ok == nil then
		ngx.log(ngx.INFO, "sadd: ",response.msg.order_sn, " is error.");
		return false;
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
		ngx.log(ngx.ERR, "comm_function failed, sending response");
		ctx.code, ctx.msg = "", reason.system_error;
		goto send;
    end
    -- Request check.
    if check_request(request, ctx) ~= true then
		ngx.log(ngx.ERR, "check_request failed, sending response");
		goto send;
    end
	-- Order Generated to web
	if generated_order(request, ctx, response) ~= true then
		ngx.log(ngx.ERR, "generated_order failed.")
		goto send;
	end	
    -- Begin of `Response'.
    ::send:: do
        if send_response(request, ctx, response) ~= true then
            ngx.log(ngx.ERR, "send_response failed");
        end
    end
	-- record logs
	if response.msg.order_sn and #response.msg.order_sn > 0 then
		if record_logs(request,response) ~= true then
			ngx.log(ngx.ERR, "record_logs failed.")
		end	
	end
		
	--关闭数据库
	if close_redis(request) ~= true then
		ngx.log(ngx.INFO, "merch_no: ",request.post_fields.merch_no, " close redis failed");
	end

    ngx.log(ngx.INFO, "The final ctx: ",(cjson.encode(ctx)),"order end, quit");
end


main();