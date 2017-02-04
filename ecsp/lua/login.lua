--作者：宫丹
--创建时间: 2016-11-29
--描述：持卡人认证
 
local cjson = require ("cjson.safe");
local common = require ("comm");
local reason = require("error_msg");
local comm_function = common.comm_function;
local pool_red = common.redis_connect;
local close_redis = common.redis_disconnect;

--处理登录信息
local function handle_login_info(request, ctx)
	local red = request.red;
	local password, err = red:hget("term:password", "password");
	if password == nil or password == ngx.null then
		ngx.log(ngx.WARN, "password empty, exit");
        ctx.code, ctx.msg = "XX",reason.password_error;
		return false;
	end
	if password == request.post_fields.password then
		 ctx.code, ctx.msg = "00",reason.login_success;
	else
		 ctx.code, ctx.msg = "XX",reason.password_error;
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
	if not request.post_fields.password or #request.post_fields.password == 0 then
        ngx.log(ngx.WARN, "password empty, exit");
        ctx.code, ctx.msg = "XX",reason.password_empty;
		return false;
    end
	return true;
end

local function login_main()
	local request, ctx  = {}, {};
	ctx.code, ctx.msg = "", reason.system_error;
	
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
	
	--链接redis数据库
	if pool_red(request) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " connect redis failed");
		ctx.code, ctx.msg = "XX", reason.data_base_error;
		goto send;
	end

	--处理请求报文
	if handle_login_info(request, ctx) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " handle_login_info is failed");
		goto send;
	end
		
	--发送返回报文
	::send:: do
		local login_info = {term_no = request.post_fields.term_no, merch_no = request.post_fields.merch_no, code = ctx.code, msg = ctx.msg};
		local message = cjson.encode(login_info);
		ngx.log(ngx.INFO, "term_no: ", request.post_fields.term_no, "  message:",message);
		ngx.print(message);
		ngx.eof();
	end
		--关闭数据库
	if close_redis(request) ~= true then
		ngx.log(ngx.INFO, "term_no: ",request.post_fields.term_no, " close redis failed");
	end
	return true;
end
login_main()
