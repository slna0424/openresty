--20161205 by ln--
local cjson = require("cjson.safe");


function parse_request(request)
    request.uri_args, request.post_fields = {}, {};
    -- Check request method.
    if ngx.var.request_method ~= "POST" then
        ngx.log(ngx.WARN, "Request method ", ngx.var.request_method, " not allowed, exit");
        ngx.exit(ngx.HTTP_NOT_ALLOWED); -- Exit: HTTP response code 405.
    end
    -- URI arguments parse.
    request.uri_args = ngx.req.get_uri_args();
    if not request.uri_args then
        ngx.log(ngx.WARN, "get_uri_args empty, exit");
        ngx.exit(ngx.HTTP_BAD_REQUEST); -- Exit: HTTP response code 400.
    end
    -- Post fields JSON parse.
    ngx.req.read_body();
    local http_body = ngx.req.get_body_data();
    if not http_body then
        local file_name = ngx.req.get_body_file();
        if file_name then
            http_body = read_file(file_name);
        end
    end
    if http_body then
        ngx.log(ngx.INFO, "Request http_body: ", http_body);
        request.post_fields = cjson.decode(http_body);
        if not request.post_fields or request.post_fields == cjson.null then
            ngx.log(ngx.WARN, "cjson.decode empty, exit");
            ngx.exit(ngx.HTTP_BAD_REQUEST); -- Exit: HTTP response code 400.
        end
    end
    return true;
end

local function check_request(request)
    -- terminal.
    if not request.post_fields.term_no or #request.post_fields.term_no == 0 then
        ngx.log(ngx.WARN, "terminal empty, exit");
        ngx.exit(ngx.HTTP_BAD_REQUEST); -- Exit: HTTP response code 400.
    end
	if not request.post_fields.merch_no or #request.post_fields.merch_no == 0 then
		ngx.log(ngx.WARN, "merch_no empty, exit");
		ngx.exit(ngx.HTTP_BAD_REQUEST); -- Exit: HTTP response code 400.
	end
	-- card_no
	if not request.post_fields.card_no or #request.post_fields.card_no == 0 then
        ngx.log(ngx.WARN, "card_no empty, exit");
        ngx.exit(ngx.HTTP_BAD_REQUEST); -- Exit: HTTP response code 400.
    end
	for i=1, #request.post_fields.order_info do
		if not request.post_fields.order_info[i].chanl_no or #request.post_fields.order_info[i].chanl_no == 0 then
			ngx.log(ngx.WARN, "chanl_no empty, exit");
			ngx.exit(ngx.HTTP_BAD_REQUEST); -- Exit: HTTP response code 400.
		end
		--pro_price
		if not request.post_fields.order_info[i].pro_price or #request.post_fields.order_info[i].pro_price == 0 then
			ngx.log(ngx.WARN, "pro_price empty, exit");
			ngx.exit(ngx.HTTP_BAD_REQUEST); -- Exit: HTTP response code 400.
		end
		--order_no
		if not request.post_fields.order_info[i].order_no or #request.post_fields.order_info[i].order_no == 0 then
			ngx.log(ngx.WARN, "order_no empty, exit");
			ngx.exit(ngx.HTTP_BAD_REQUEST); -- Exit: HTTP response code 400.
		end	
		--order_payway
		if not request.post_fields.order_info[i].order_payway or #request.post_fields.order_info[i].order_payway == 0 then
			ngx.log(ngx.WARN, "transaction channel empty, exit");
			ngx.exit(ngx.HTTP_BAD_REQUEST); -- Exit: HTTP response code 400.
		end
		--pay_state
		if not request.post_fields.order_info[i].pay_state or #request.post_fields.order_info[i].pay_state == 0 then
			ngx.log(ngx.WARN, "transaction channel empty, exit");
			ngx.exit(ngx.HTTP_BAD_REQUEST); -- Exit: HTTP response code 400.
		end
	end

    return true;
end
-- response to terminal 
local function send_response(request, ctx, response)
    response.msgs = {};

    response.msgs.term_no = request.post_fields.term_no or "";  -- Default empty.
    response.msgs.merch_no = request.post_fields.merch_no or "";
    response.msgs.code = ctx.ret_code or "";
    response.msgs.msg = "";
    response.message = cjson.encode(response.msgs);
    ngx.print(response.message);
	ngx.log(ngx.INFO,"msg:",response.message);
    ngx.eof();
    return true;
end

local function main()
    ngx.log(ngx.INFO, "now process request ...");
    -- Context & generic data.
    local request, ctx, response = {}, {}, {};
    --ctx.time = system_time();
    ctx.ret_code = "00";
    -- Begin of `Parse'.
    if parse_request(request, ctx) ~= true then
        ngx.log(ngx.ERR, "parse_request failed, sending response");
        if ctx.ret_code == "00" then
            --ctx.ret_code = "";    -- Parse unknown failure.
        end
        goto send;
    end
    -- Request check.
    if check_request(request) ~= true then
        if ctx.ret_code == "00" then
            --ctx.ret_code = "";    -- Request check unknown failure.
        end
        goto send;
    end
	--[[
	-- Order Generated to web
	if generated_order(request, ctx, response) ~= true then
		ngx.log(ngx.ERR, "generated_order failed.")
		if ctx.ret_code == "00" then
            --ctx.ret_code = "";    -- generated_order failure.
        end
		goto send;
	end
	-- record logs
	if record_logs(request, ctx, response) ~= true then
		ngx.log(ngx.ERR, "record_logs failed.")
		if ctx.ret_code == "00" then
		--ctx.ret_code = "";    -- generated_order failure.
		end
		goto send;
	end
	--]]
    -- Begin of `Response'.
    ::send:: do
        if send_response(request, ctx, response) ~= true then
            ngx.log(ngx.ERR, "send_response failed");
        --    ctx.ret_code = "";  
        end

        ngx.log(ngx.INFO, "Send response: [", response.message, "]");
    end
    ngx.log(ngx.INFO, "The final ctx: ", (cjson.encode(ctx)));
    ngx.log(ngx.INFO, "Arbiter end, quit");
end


main();