--下载脚本
 
local cjson = require ("cjson.safe");
local common = require ("comm");
local path = require("path");
local script_name = require("script_name");
local comm_function = common.comm_function;


local function script_main()
	local script, trans = nil, nil;
	local code,msg = "00","";
	local request ={};
	if comm_function(request) ~= true then
		ngx.log(ngx.INFO, "term: ",request.post_fields.term_no, " rcv request msg failed");
		code, msg = "", reason.system_error;
		goto send;
	end
	trans = request.post_fields.trans;
	back = request.post_fields.script;
	ngx.log(ngx.INFO, "term: ",request.post_fields.term_no," trans: ", trans);

	if "t_gmenu" == trans and "" == back then
		script = path.script_path .. script_name.menu_script;         --菜单
	elseif "t_glist" == trans and "" == back then
		script = path.script_path .. script_name.prolist_script;      --商品列表
	elseif "t_login" == trans and "" == back then
		script = path.script_path .. script_name.login_script;        --登录
	elseif "t_logout" == trans and "" == back then
		script = path.script_path .. script_name.logout_script;       --登出
	elseif "t_proinfo" == trans and "" == back then 
		script = path.script_path .. script_name.proinfo_script;      --商品详情
	elseif "t_cart" == trans and "" == back then
		script = path.script_path .. script_name.cart_script;         --查看购物车
	elseif "t_favorite" == trans and "" == back then                                 
		script = path.script_path .. script_name.favorite_script;     --查看收藏夹
	elseif "t_query" == trans and "" == back then
		script = path.script_path .. script_name.query_script;        --订单查询
	elseif "t_order" == trans and "" == back then
		script = path.script_path .. script_name.order_script;        --下单
	elseif "t_addcart" == trans and "" == back then
	    script = path.script_path .. script_name.addcart_script;      --加入购物车
	elseif "t_addfavorite" == trans and "" == back then
	    script = path.script_path .. script_name.addfav_script;       --加入收藏夹
	elseif "t_gback" == trans and "t_gmenu" == back then
		script = path.script_path .. script_name.zmenu_script;        --返回主界面
	elseif "t_gback" == trans and ("t_glist" == back or "t_cart" == back or "t_favorite" == back or "t_login" == back or "t_order" == back or "t_payway" == back or "t_orderlist" == back) then
		script = path.script_path .. script_name.menu_script;         --返回菜单
	elseif "t_gback" == trans and ("t_proinfo" == back  or "t_query" == back or "t_goodsinfo" == back) then
		script = path.script_path .. script_name.prolist_script;      --返回列表
	elseif "t_payway" == trans and "" == back then
		script = path.script_path .. script_name.payway_script;       --支付方式选择
	elseif "t_pay01" == trans and "" == back then
		script = path.script_path .. script_name.cardpay_script;      --刷卡支付
	elseif "t_pay03" == trans and "" == back then
		script = path.script_path .. script_name.sjdpay_script;       --双基贷
	elseif "t_pay02" == trans and "" == back then
		script = path.script_path .. script_name.ptdpay_script;       --平台贷
	elseif "t_gclassfy" == trans and "" == back then
		script = path.script_path .. script_name.gclassfy_script;     --分类
	elseif "t_gtitle" == trans and "" == back then
		script = path.script_path .. script_name.gtitle_script;       --底部
	elseif "t_orderlist" == trans and "" == back then
		script = path.script_path .. script_name.orderlist_script;    --订单列表
	elseif "t_goodsinfo" == trans and "" == back then
		script = path.script_path .. script_name.goodsinfo_script;
	end
	
	::send:: do
		local scriptinfo = {term_no = request.post_fields.term_no, merch_no = request.post_fields.merch_no, code = code, msg = msg, script = script};
		local message = cjson.encode(scriptinfo);
		local res = string.gsub(message, "\\","");
		ngx.log(ngx.INFO, "message:",res);
		ngx.print(res);
		ngx.eof();
	end
	return true;
end
script_main()
