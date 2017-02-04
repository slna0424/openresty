--作者：宫丹
--创建时间: 2016-12-21
--描述：数据同步
 
local cjson = require ("cjson.safe");
local common = require ("comm");
local pool_mysql = common.mysql_connect;
local close_mysql = common.mysql_disconnect;
local pool_red = common.redis_connect;
local close_redis = common.redis_disconnect;

local function data_sync_info(request)
	local order_data, err = request.red:smembers("order_sum:");
	if order_data == nil then
		ngx.log(ngx.INFO, "order_data is empty", "err: ", err);
		return false;
	end
	local t = ngx.time() - 24 * 3600;
	ngx.log(ngx.INFO, "t: ",t);
	local get_date = os.date("%Y-%m-%d", tostring(t));
	ngx.log(ngx.INFO, "get_date: ",get_date);
	
	ngx.log(ngx.INFO, "order_data: ", #order_data);
	for i = 1, #order_data do
		local order_key = string.format("order:%s", order_data[i]);
		local order_info, err = request.red:hmget(order_key, "money_discount", "money_product", "money_order", "money_price", "money_product_trade", "money_order_trade","money_price_trade","money_logistics","money_coupon", "money_act_full","term_no", "status", "jszh", "date");	
		if order_info == nil then
			ngx.log(ngx.INFO, "order_info is empty", "err: ", err);
			return false;
		end
		if get_date == order_info[14] then
			local sql = string.format("insert into order_info (money_discount, money_product, money_order, money_price, money_product_trade, money_order_trade,money_price_trade,money_logistics,money_coupon, money_act_full,term_no, status, jszh, date,order_no) values('%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s');",
			    order_info[1], order_info[2], order_info[3], order_info[4], order_info[5], order_info[6], order_info[7], order_info[8], order_info[9], order_info[10], order_info[11], order_info[12], order_info[13], order_info[14], order_data[i]);
			local res, err, errcode, sqlstate = request.db:query(sql)
			if not res then
				ngx.log(ngx.ERR," bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
				return false;
			end
		end
	end
	return true;
end

local function sync_main()
	local request = {};
	--链接redis数据库
	if pool_red(request) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " connect redis failed");
		return false;
	end
	--链接mysql数据库
	if pool_mysql(request) ~= true then
		ngx.log(ngx.INFO, "mysql_connect failed");
		return false;
	end
	
	if data_sync_info(request) ~= true then
		ngx.log(ngx.INFO, "data_sync_info failed");
		return false;
	end
		--关闭redis数据库
	if close_redis(request) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " close redis failed");
		return false;
	end
	--关闭mysql数据库
	if close_mysql(request) ~= true then
		ngx.log(ngx.INFO, "close_mysql failed");
		return false;
	end
	return true;
end
sync_main()
