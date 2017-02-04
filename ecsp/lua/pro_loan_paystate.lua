--作者：宫丹
--创建时间: 2016-12-19
--描述：贷款结算
 
local cjson = require ("cjson.safe");
local common = require ("comm");
local reason = require("error_msg");
local path = require("path");
local comm_function = common.comm_function;
local send_or_rcv_msg = common.send_or_rcv_msg;
local mysql_connect = common.mysql_connect;
local close_mysql = common.mysql_disconnect;

--处理贷款结算信息
local function handle_paystate_info(request, ctx)
	local time = ngx.localtime();
	local order_no = "";
	for i = 1, #request.post_fields.v_order_info do
		if i == #request.post_fields.v_order_info then
			order_no = order_no .. request.post_fields.v_order_info[i].order_no;
		else
			order_no = order_no .. request.post_fields.v_order_info[i].order_no .. "|";
		end		
		ngx.log(ngx.INFO, "order_no: ",order_no);
	end
	local sql = string.format("insert into zd_dkxx (zdbh, shbh, sfzh, jyje, qx, dhhm, gxsj, payment_code, payment_name, ddbh) values('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s');", request.post_fields.term_no, request.post_fields.merch_no, request.post_fields.cert_no, request.post_fields.businesssum, request.post_fields.termmonth, request.post_fields.tel_no, time, request.post_fields.pwyid, request.post_fields.pwyname, order_no);
	ngx.log(ngx.INFO, "sql: ", sql);
	local res, err, errcode, sqlstate = request.db:query(sql)
	if not res then
		ngx.log(ngx.ERR," bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
		ctx.code, ctx.msg = "XX", reason.data_base_error;
		return false;
	end
	return true;
end

--校验请求报文
local function check_request(request, ctx)

	if not request.post_fields.term_no or #request.post_fields.term_no == 0 then
        ngx.log(ngx.WARN, "terminal empty, exit");
        ctx.code, ctx.msg = "XX",reason.term_no_empty;
		return false;
    end
    if not request.post_fields.merch_no or #request.post_fields.merch_no == 0 then
        ngx.log(ngx.WARN, "merch_no empty, exit");
        ctx.code, ctx.msg = "XX",reason.card_no_empty;
		return false;
    end
	if not request.post_fields.cert_no or #request.post_fields.cert_no == 0 then
        ngx.log(ngx.WARN, "cert_no empty, exit");
        ctx.code, ctx.msg = "XX",reason.cert_no_empty;
		return false;
    end
	if not request.post_fields.pwyname or #request.post_fields.pwyname == 0 then
        ngx.log(ngx.WARN, "pwyname empty, exit");
        ctx.code, ctx.msg = "XX",reason.order_payway_empty;
		return false;
    end
	if not request.post_fields.pwyid or #request.post_fields.pwyid == 0 then
        ngx.log(ngx.WARN, "pwyname empty, exit");
        ctx.code, ctx.msg = "XX",reason.order_payway_empty;
		return false;
    end
	if not request.post_fields.businesssum or #request.post_fields.businesssum == 0 then
        ngx.log(ngx.WARN, "businesssum empty, exit");
        ctx.code, ctx.msg = "XX",reason.businesssum_empty;
		return false;
    end
	if not request.post_fields.termmonth or #request.post_fields.termmonth == 0 then
        ngx.log(ngx.WARN, "termmonth empty, exit");
        ctx.code, ctx.msg = "XX",reason.termmonth_empty;
		return false;
    end
	if not request.post_fields.tel_no or #request.post_fields.tel_no == 0 then
        ngx.log(ngx.WARN, "tel_no empty, exit");
        ctx.code, ctx.msg = "XX",reason.tel_no_empty;
		return false;
    end
	--[[
	if not request.post_fields.trans_no or #request.post_fields.trans_no == 0 then
        ngx.log(ngx.WARN, "trans_no empty, exit");
        ctx.code, ctx.msg = "XX",reason.trans_no_empty;
		return false;
    end
	if not request.post_fields.batch_no or #request.post_fields.batch_no == 0 then
        ngx.log(ngx.WARN, "batch_no empty, exit");
        ctx.code, ctx.msg = "XX",reason.batch_no_empty;
		return false;
    end
	--]]
	for i = 1, #request.post_fields.v_order_info do
		if not request.post_fields.v_order_info[i].order_no or #request.post_fields.v_order_info[i].order_no == 0 then
			ngx.log(ngx.WARN, "order_no empty, exit");
			ctx.code, ctx.msg = "XX",reason.order_no_empty;
			return false;		
		end
		if not request.post_fields.v_order_info[i].pro_price or #request.post_fields.v_order_info[i].pro_price == 0 then
			ngx.log(ngx.WARN, "pro_price empty, exit");
			ctx.code, ctx.msg = "XX",reason.pro_price_empty;
			return false;
		end
	end
	return true;
end

--发送、接收电商平台响应
local function put_paystate(request, ctx, response)
	local send_msg,v_order_info = {},{};
	send_msg.merch_no = request.post_fields.merch_no or "";
	send_msg.name = request.post_fields.card_no or "000000";
	send_msg.payment_code = request.post_fields.pwyid or "";
	send_msg.payment_name = request.post_fields.pwyname or "";
	--todo 去交易流水中去查
	send_msg.payment_status = "3";   --1.成功，2.失败    3.贷款 		
	send_msg.pay_sn = "000000";           	--lsbh  todo
	local index = (request.post_fields and request.post_fields.v_order_info and #request.post_fields.v_order_info) or 0;
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

local function paystate_main()
	local request, ctx, response  = {}, {}, {};
	ctx.code, ctx.msg = "00", "";
	
	--接收C端请求报文
	if comm_function(request) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " rcv request msg failed");
		ctx.code, ctx.msg = "", reason.system_error;
		goto send;
	end
	
	--校验请求报文
	if check_request(request, ctx) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " rcv request msg failed");
		goto send;
	end
	
	--链接mysql数据库
	if mysql_connect(request) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " connect redis failed");
		ctx.code, ctx.msg = "XX", reason.data_base_error;
		goto send;
	end

	--处理请求报文
	if handle_paystate_info(request, ctx) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " handle_login_info is failed");
		goto send;
	end
	
	if put_paystate(request, ctx, response) ~= true then
		ngx.log(ngx.ERR, "put_paystate failed.")
		goto send;
	end
		
	--发送返回报文
	::send:: do
		local note_info = "您的贷款请求已受理，24小时之内客户经理会与您联系，请保持电话畅通";
		local login_info = {term_no = request.post_fields.term_no, merch_no = request.post_fields.merch_no, code = ctx.code, msg = ctx.msg, note_info = note_info};
		local message = cjson.encode(login_info);
		ngx.log(ngx.INFO, "term_no: ", request.post_fields.term_no, "  message:",message);
		ngx.print(message);
		ngx.eof();
	end
	--关闭数据库
	if close_mysql(request) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " close redis failed");
	end
	return true;
end
paystate_main()
