--错误提示

local ok, new_tab = pcall(require, "table.new");
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 32);
_M._VERSION = "0.1";

_M.login_success = "登录成功";
_M.input_tel_no = "请输入电话号码";
_M.system_error = "系统异常";
_M.term_no_empty = "终端编号为空";
_M.card_no_empty = "卡号为空";
_M.chanl_no_empty = "渠道编号为空";
_M.page_no_empty = "请求页数为空";
_M.page_num_empty = "请求一页的个数为空";
_M.merch_no_empty = "商户编号为空";
_M.sku_no_empty = "sku为空";
_M.order_no_empty = "订单编号为空";
_M.price_empty = "商品价格为空";
_M.pay_state_empty = "支付状态为空";
_M.order_payway_empty = "支付方式为空";
_M.sku_num_empty = "商品个数为空";
_M.shop_id_empty = "店铺id参数为空";
_M.trans_params_empty = "交易要素为空";
_M.order_state_empry = "订单状态为空";
_M.cafy_id_empty = "商品分类编号为空";
_M.password_empty = "密码为空";
_M.password_error = "密码错误";
_M.cert_no_empty = "身份证号为空";
_M.businesssum_empty = "贷款金额为空";
_M.termmonth_empty = "贷款期限为空";
_M.tel_no_empty = "联系方式为空";
_M.pro_price_empty = "订单金额为空";
_M.data_base_error = "数据库操作失败";
_M.trans_no_empty = "终端流水号为空";
_M.batch_no_empty = "终端批次号为空";


return _M;
