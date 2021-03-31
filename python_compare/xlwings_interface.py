from common import util
import xlwings as xw
import numpy as np
import datetime as dt
import pandas as pd
from svi import volsurface as vs
from black import blackscholes as bs
from common import conf
from common.conf import RibbonCompare
from common.expiry import UnderlyingExpiry
import common.date as date
import data.marketdata as md
import script.calculate_forward_vols as cfv
from svi import svi_core as sc
from ah import ah_core as ac

__author__ = 'astriker'
__version__ = '0.5.6'

logger = util.get_logger('volsurface')
util.ignore_warnings(True)


def world():
    wb = xw.Book.caller()
    wb.sheets('debug').range('A1').value = 'Hello World!'


@xw.func
def hello(name):
    s = 'Hello {}'.format(name)
    print(s)
    return s


@xw.func
def hello2(name):
    s = 'Hello2 {}'.format(name)
    print(s)
    return s


@xw.func()
def volsurface_version():
    return __version__


@xw.func
def vkospi_forward(r, now_dt, expiry_dt, strikes, call_values, put_values):
    diff = expiry_dt - now_dt
    t = diff.total_seconds() / conf.YEAR_SECONDS
    df = np.exp(-r * t)
    acc = 1 / df

    strikes = np.array(strikes, dtype=float)
    call_values = np.array(call_values, dtype=float)
    put_values = np.array(put_values, dtype=float)
    idx = np.abs(call_values - put_values).argmin()
    f = strikes[idx] + acc * (call_values[idx] - put_values[idx])
    ret = f
    return ret


def vkospi_variance(r, t, f, strikes, call_values, put_values, useyn):
    strikes = np.array(strikes, dtype=float)
    call_values = np.array(call_values, dtype=float)
    put_values = np.array(put_values, dtype=float)
    useyn = np.array(useyn, dtype=bool)
    if useyn.any():
        strikes = strikes[useyn]
        call_values = call_values[useyn]
        put_values = put_values[useyn]

    acc = np.exp(r * t)
    k = strikes[strikes <= f][-1]
    idx = strikes.tolist().index(k)
    dk = strikes[1] - strikes[0]
    p_sum = (put_values[:idx] / strikes[:idx]**2).sum() * dk + 0.5 * put_values[idx] / strikes[idx]**2 * dk
    c_sum = (call_values[idx+1:] / strikes[idx+1:]**2).sum() * dk + 0.5 * call_values[idx] / strikes[idx]**2 * dk
    variance = acc * 2 / t * (c_sum + p_sum) - 1 / t * (f / k - 1)**2
    return variance


@xw.func
def vkospi_price(r, now_dt, expiry_dt, f, strikes, call_values, put_values, expiry_dt2, f2, strikes2, call_values2, put_values2, useyn=None, useyn2=None):
    diff = expiry_dt - now_dt
    t = diff.total_seconds() / conf.YEAR_SECONDS
    variance = vkospi_variance(r, t, f, strikes, call_values, put_values, useyn)
    if diff >= dt.timedelta(30):
        vkospi = np.sqrt(variance) * 100
        return vkospi

    diff2 = expiry_dt2 - now_dt
    t2 = diff2.total_seconds() / conf.YEAR_SECONDS
    variance2 = vkospi_variance(r, t2, f2, strikes2, call_values2, put_values2, useyn2)

    t30 = 30 / conf.YEAR_DAY
    w = variance * t * (t2 - t30) / (t2 - t) + variance2 * t2 * (t30 - t) / (t2 - t)
    vkospi = np.sqrt(w / t30) * 100
    return vkospi


@xw.func
def black(f, k, now_dt, expiry_dt, r, v, cpflag='call'):
    t = (expiry_dt - now_dt).total_seconds() / conf.YEAR_SECONDS
    iv = bs._black(f, k, v, t, r, cpflag=cpflag)
    return iv


@xw.func
def black_iv(f, k, now_dt, expiry_dt, r, p, cpflag='call'):
    t = (expiry_dt - now_dt).total_seconds() / conf.YEAR_SECONDS
    iv = bs.black_impliedvol(f, k, t, r, p, cpflag=cpflag)
    return iv


@xw.func
def calibrate_raw_svi(f, t, strikes, ivs, method='SLSQP'):
    f = float(f)
    t = float(t)
    strikes = np.array(strikes, dtype=float)
    ivs = np.array(ivs, dtype=float)
    raw = sc.RAW_SVI(f, t, strikes, ivs, method=method)
    res = raw.calibrate()
    return res


@xw.func
def get_raw_svi_iv(f, t, k, args):
    f = float(f)
    k = float(k)
    args = np.array(args, dtype=float)
    return sc.RAW_SVI.get_raw_svi_iv(f, t, k, args)


@xw.func
def convert_raw_to_jw(f, t, raw_params, trader_jw=False):
    f = float(f)
    t = float(t)
    raw_params = np.array(raw_params, dtype=float)

    res = sc.RAW_SVI.get_jw_params(f, t, raw_params)
    if trader_jw:
        res = sc.SVI_JW.convert_params_original_to_trader(res)
    return res


@xw.func
def get_ivs_info(basedate, ivs, fwds, fwd_dates):
    if not isinstance(basedate, dt.datetime):
        Exception('basedate must be datetime')
    fwds = np.array(fwds, dtype=float)
    df, skews, _ = sc.make_fit_info(basedate, ivs, fwds)
    return df[['expiry', 'yearfrac', 'forward', 'iv_atm', 'w_atm']]


@xw.func
def calibrate_ssvi(basedate, spot, ivs, fwds, fwd_dates, method='SLSQP'):
    spot = float(spot)
    if not isinstance(basedate, dt.datetime):
        Exception('basedate must be datetime')
    if not isinstance(fwds, list):
        fwds = [fwds]
    if not isinstance(fwd_dates, list):
        fwd_dates = [fwd_dates]
    fwds = np.array(fwds, dtype=float)
    fwd_dates = np.array(fwd_dates, dtype=dt.datetime)

    ssvi = sc.Surface_SVI(basedate, fwds, fwd_dates, ivs, method=method)
    df = pd.DataFrame(data=ssvi.calibrate(), columns=conf.SVI_PARAMETERS)
    return df


@xw.func
def calibrate_svi_jw(basedate, ivs, fwds, fwd_dates, inits=None, method='SLSQP', trader_jw=False):
    if not isinstance(basedate, dt.datetime):
        Exception('basedate must be datetime')
    if not isinstance(fwds, list):
        fwds = [fwds]
    if not isinstance(fwd_dates, list):
        fwd_dates = [fwd_dates]
    fwds = np.array(fwds, dtype=float)
    fwd_dates = np.array(fwd_dates, dtype=dt.datetime)
    inits = [None for _ in range(len(fwd_dates))]
    df, skews, _ = sc.make_fit_info(basedate, ivs, fwds)

    res = []
    for f, t, skew, init in zip(df['FORWARD'].values, df['YEARFRAC'].values, skews, inits):
        jw = sc.SVI_JW(f, t, ks=skew.index.values, ivs=skew.values, method=method)
        res.append(jw.calibrate(x0=init, disp=True))
    res_df = pd.DataFrame(data=res, columns=['v', 'psi', 'p', 'c', 'vt'])
    if trader_jw:
        res_df = sc.SVI_JW.convert_params_original_to_trader(res_df)
    return res_df


@xw.func
def get_svi_jw_iv(f, t, k, args, trader_jw=False):
    f = float(f)
    t = float(t)
    k = float(k)
    args = np.array(args, dtype=float)
    if trader_jw:
        args = sc.SVI_JW.convert_params_trader_to_original(args)
    jw = sc.SVI_JW(f, t)
    return jw.get_iv(args, k)


@xw.func
def convert_jw_to_raw(f, t, jw_params, trader_jw=False):
    f = float(f)
    t = float(t)
    jw_params = np.array(jw_params, dtype=float)
    if trader_jw:
        jw_params = sc.SVI_JW.convert_params_trader_to_original(jw_params)
    jw = sc.SVI_JW(f, t)
    return jw.get_raw_params(jw_params)


@util.fd_timer
@xw.func
def xw_btn_load_data(compare):
    sheet = xw.sheets.active
    sheet = go_proper_sheet(sheet)
    sheet.range('_CONTENT_ALL_').clear()
    xw.apps.active.screen_updating = False

    ribbon_compare = RibbonCompare(int(compare))

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    undcode = sheet.range('UNDCODE_').value
    source = sheet.range('SOURCE_').value
    sheet.range('CALIBRATE_TYPE_').value = None
    tag = sheet.range('TAG_').value

    msg = []
    vol_tu = vs.load_info(basedt, source, undcode, tag)
    params_df = vol_tu.params_df
    ivs_df = None
    if params_df is not None:
        ivs_df = vs.ivs_by_parameters(vol_tu.forward_df, vol_tu.strikes, params_df, column_to_str=True)
    if vol_tu.raw_forward_df is not None:
        write_load_data(sheet, vol_tu, params_df, ivs_df)
    else:
        sheet.range('_ORG_SPOT_').value = 'no data'

    if params_df is not None and ribbon_compare > 0:
        _msg = compare_data_and_write_in_fit_sheet(sheet, ribbon_compare, vol_tu.strikes, vol_tu.forward_df, params_df,
                                                   vol_tu.raw_forward_df, vol_tu.raw_ivs_df,
                                                   basedt, source, undcode, tag, None)
        if _msg:
            msg.append(_msg)

    xw.apps.active.screen_updating = True
    sheet.range('_ORG_FORWARD_').select()
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_recent_vol_data():
    res_df = vs.recent_vol_data()
    return res_df.to_string()


@util.fd_timer
@xw.func
def xw_btn_compare_parameters():
    sheet = xw.sheets.active
    set_fit_sheet_args_to_compare_sheet(sheet)
    sheet = go_proper_sheet(sheet, sheetname='compare', name='COMPARE_STRIKE_RULE_')

    strike_rule = conf.StrikeRule(get_sw_value(sheet.range('COMPARE_STRIKE_RULE_').value, 'SW_STRIKE_RULE_LIST'))
    strikes = None
    if strike_rule == conf.StrikeRule.Excel_Strike:
        strikes = sheet.range('_BASE_VOLSURFACE_').expand('right').value
        if not strikes:
            return 'no Excel Strikes'
        if not isinstance(strikes, list):
            strikes = [strikes]
        strikes = np.array(strikes)

    maturity_rule = conf.StrikeRule(get_sw_value(sheet.range('COMPARE_MATURITY_RULE_').value, 'SW_MATURITY_RULE_LIST'))
    mats = None
    if maturity_rule == conf.MaturityRule.Excel_Maturity:
        mats = sheet.range('_BASE_FORWARD_').offset(1, 1).expand('down').value
        if not mats:
            return 'no Excel Maturities'
        if not isinstance(mats, list):
            mats = [mats]
        mats = np.array(mats)

    sheet.range('_CONTENT_ALL_').clear()
    xw.apps.active.screen_updating = False

    base_dt = date.to_date(sheet.range('BASE_DATE_').value).strftime('%Y%m%d')
    base_source = sheet.range('BASE_SOURCE_').value
    base_undcode = sheet.range('BASE_UNDCODE_').value
    base_tag = sheet.range('BASE_TAG_').value
    target_dt = date.to_date(sheet.range('TARGET_DATE_').value).strftime('%Y%m%d')
    target_source = sheet.range('TARGET_SOURCE_').value
    target_undcode = sheet.range('TARGET_UNDCODE_').value
    target_tag = sheet.range('TARGET_TAG_').value

    msg = []
    raw_base_dic = vs.load_compare_info(base_dt, base_source, base_undcode, base_tag)
    if not raw_base_dic['data']:
        msg.append('there is no BASE data')
    raw_target_dic = vs.load_compare_info(target_dt, target_source, target_undcode, target_tag)
    if not raw_target_dic['data']:
        msg.append('there is no TARGET data')
    if raw_base_dic['data'] and raw_target_dic['data']:
        base_dic = vs.adjust_base_dic(raw_base_dic, strike_rule, strikes, maturity_rule, mats)
        target_dic = vs.adjust_target_dic(raw_target_dic, base_dt, base_dic['strikes'], maturity_rule,
                                          base_dic['mats'])
        write_compare_parameters(sheet, base_dic, target_dic, maturity_rule)
    xw.apps.active.screen_updating = True
    sheet.range('A1').select()
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_save_forward():
    sheet = xw.sheets.active
    sheet = go_proper_sheet(sheet, 'forward', name='_FORWARD_')
    xw.apps.active.screen_updating = False

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    undcode = sheet.range('UNDCODE_').value
    source = sheet.range('SOURCE_').value
    tag = sheet.range('TAG_').value

    msg = []
    if source in ['NICE', 'KAP'] and tag == 'EOD':
        msg.append("source[NICE, KAP] can't save forward with tag=EOD")
        return '\n'.join(msg)
    if source == 'BLOOMBERG' and tag != 'EOD':
        msg.append("source=BLOOMBERG for saving forward must be with tag=EOD")
        return '\n'.join(msg)

    spot = sheet.range('_FILL_SPOT_').offset(0, 1).value
    forwards = sheet.range('_FILL_FORWARD_').offset(1, 0).expand().value
    forward_df = pd.DataFrame(data=forwards, columns=['EXPIRY', 'FORWARD'])
    forward_df['MATURITY'] = [date.to_date(e).strftime('%Y%m%d') for e in forward_df['EXPIRY'].values]
    forward_df = forward_df.dropna()
    vs.save_parameters(basedt, source, undcode, tag, spot, forward_df, None, save_forward=True, save_params=False)
    xw.apps.active.screen_updating = True
    msg += ['success to save forward', f'BASEDATE={basedt}, SOURCE={source}, UNDCODE={undcode}',
            f'TAG={tag}']
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_fill_forward():
    sheet = xw.sheets.active
    sheet = go_proper_sheet(sheet, 'forward', name='_FORWARD_')
    sheet.range('_FILL_SPOT_').expand('right').clear()
    sheet.range('_FILL_FORWARD_').expand().clear()
    xw.apps.active.screen_updating = False

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    undcode = sheet.range('UNDCODE_').value
    source = sheet.range('SOURCE_').value
    tag = sheet.range('TAG_').value
    fill_forward_method = conf.FFillMethod(get_sw_value(sheet.range('FILL_NA_FORWARD_').value, 'SW_FILL_NA_FORWARD_LIST'))

    msg = []
    ue = UnderlyingExpiry(undcode, basedt)
    und_maturities = ue.expiry_dts
    forward_df, spot = vs.get_forwards(basedt, source, undcode, tag)
    if forward_df is None:
        forward_df, spot = vs.get_forwards(basedt, source, undcode, 'EOD')
    forward_df = util.outer_join_keys(und_maturities, forward_df)
    forward_df['EXPIRY'] = pd.to_datetime(forward_df.index)
    forward_df['MATURITY'] = forward_df.index
    if any(pd.isnull(forward_df)):
        forward_df['F'] = forward_df['FORWARD']
        cfv.fill_na_forward(basedt, undcode, source, tag, fill_forward_method, forward_df)
        forward_df['FORWARD'] = forward_df['F']
        forward_df = forward_df.drop(columns=['F'])

    forward_df['DIFF'] = forward_df['FORWARD'].diff()
    sheet.range('_FILL_SPOT_').value = 'spot'
    sheet.range('_FILL_SPOT_').offset(0, 1).value = spot
    sheet.range('_FILL_FORWARD_').options(index=False).value = forward_df[['EXPIRY', 'FORWARD', 'DIFF']]
    sheet.range('_FILL_FORWARD_').value = 'forward'

    xw.apps.active.macro('applyFormatForwardNumberFormat')(sheet.range('_FILL_SPOT_').offset(0, 1).address)
    address = xw.Range(sheet.range('_FILL_FORWARD_').offset(0, 1),
                       sheet.range('_FILL_FORWARD_').offset(len(forward_df), 2)).address
    xw.apps.active.macro('applyFormatForwardNumberFormat')(address)
    xw.apps.active.macro('applyFormatRightAlignment')(sheet.range('_FILL_SPOT_').address)
    xw.apps.active.macro('applyFormatRightAlignment')(sheet.range('_FILL_FORWARD_').expand('right').address)

    sheet.range('A1').select()
    xw.apps.active.screen_updating = True
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_load_forward():
    sheet = xw.sheets.active
    sheet = go_proper_sheet(sheet, 'forward', name='_FORWARD_')
    sheet.range('_CONTENT_ALL_').clear()
    xw.apps.active.screen_updating = False

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    source = sheet.range('SOURCE_').value
    undcode = sheet.range('UNDCODE_').value
    tag = sheet.range('TAG_').value
    blg_forward_df, blg_spot = vs.get_forwards(basedt, 'BLOOMBERG', undcode, 'EOD')
    nice_forward_df, nice_spot = vs.get_forwards(basedt, 'NICE', undcode, 'EOD')
    kap_forward_df, kap_spot = vs.get_forwards(basedt, 'KAP', undcode, 'EOD')
    prev_source_dt = md.get_recentdt_of_param_table(basedt, source, undcode, tag, 'FORWARD')
    prev_source_forward_df, prev_source_spot = vs.get_forwards(prev_source_dt, source, undcode, tag)
    fill_forward_df, fill_spot = vs.get_forwards(basedt, source, undcode, tag)

    if nice_forward_df is None:
        nice_forward_df = pd.DataFrame(columns=['MATURITY', 'FORWARD'])
    if kap_forward_df is None:
        kap_forward_df = pd.DataFrame(columns=['MATURITY', 'FORWARD'])
    if blg_forward_df is None:
        blg_forward_df = pd.DataFrame(columns=['MATURITY', 'FORWARD'])
        blg_spot = np.nan
    if prev_source_forward_df is None:
        prev_source_forward_df = pd.DataFrame(columns=['MATURITY', 'FORWARD'])
        prev_source_spot = np.nan
    if fill_forward_df is None:
        fill_forward_df = pd.DataFrame(columns=['MATURITY', 'FORWARD'])
        fill_spot = np.nan

    msg = []
    und_maturities = UnderlyingExpiry(undcode, basedt).expiry_dts
    merge_mats = und_maturities + blg_forward_df['MATURITY'].values.tolist() \
                 + nice_forward_df['MATURITY'].values.tolist() + kap_forward_df['MATURITY'].values.tolist() \
                 + prev_source_forward_df['MATURITY'].values.tolist()
    merge_mats = sorted(set(merge_mats))
    merge_df = pd.DataFrame(index=merge_mats, columns=['BLOOMBERG', 'NICE', 'KAP', f'prev {source}', 'diff with prev'])
    for maturity in merge_df.index:
        if maturity in blg_forward_df.index:
            merge_df.loc[maturity, 'BLOOMBERG'] = blg_forward_df.loc[maturity, 'FORWARD']
        if maturity in nice_forward_df.index:
            merge_df.loc[maturity, 'NICE'] = nice_forward_df.loc[maturity, 'FORWARD']
        if maturity in kap_forward_df.index:
            merge_df.loc[maturity, 'KAP'] = kap_forward_df.loc[maturity, 'FORWARD']
        if maturity in blg_forward_df.index and maturity in prev_source_forward_df.index:
            merge_df.loc[maturity, f'prev {source}'] = prev_source_forward_df.loc[maturity, 'FORWARD']
            merge_df.loc[maturity, f'diff with prev'] = blg_forward_df.loc[maturity, 'FORWARD'] - \
                                                        prev_source_forward_df.loc[maturity, 'FORWARD']
    merge_df.insert(loc=0, column='', value=pd.to_datetime(merge_df.index.values))
    merge_df.insert(loc=1, column='YSK_MATURITY', value=None)
    merge_df['YSK_MATURITY'] = [True if mat in und_maturities else None for mat in merge_mats]

    sheet.range('_SPOT_').value = 'spot'
    sheet.range('_SPOT_').offset(0, 2).value = [blg_spot, nice_spot, kap_spot, prev_source_spot,
                                                blg_spot - prev_source_spot]
    sheet.range('_FORWARD_').offset(0, 0).options(index=False).value = merge_df
    sheet.range('_FORWARD_').value = 'forward'

    xw.apps.active.macro('applyFormatRightAlignment')(sheet.range('_SPOT_').address)
    address = xw.Range(sheet.range('_FORWARD_'), sheet.range('_FORWARD_').offset(0, 6)).address
    xw.apps.active.macro('applyFormatRightAlignment')(address)

    address = xw.Range(sheet.range('_SPOT_').offset(0, 2), sheet.range('_FORWARD_').offset(len(merge_mats), 6)).address
    xw.apps.active.macro('applyFormatForwardNumberFormat')(address)

    already_forward_filled = False
    if len(fill_forward_df) == len(und_maturities):
        already_forward_filled = True

    if already_forward_filled:
        fill_forward_df['DIFF'] = fill_forward_df['FORWARD'].diff()
        sheet.range('_FILL_SPOT_').value = 'spot'
        sheet.range('_FILL_SPOT_').offset(0, 1).value = fill_spot
        sheet.range('_FILL_FORWARD_').options(index=False).value = fill_forward_df[['EXPIRY', 'FORWARD', 'DIFF']]
        sheet.range('_FILL_FORWARD_').value = 'forward'
        xw.apps.active.macro('applyFormatForwardNumberFormat')(sheet.range('_FILL_SPOT_').offset(0, 1).address)
        address = xw.Range(sheet.range('_FILL_FORWARD_').offset(0, 1),
                           sheet.range('_FILL_FORWARD_').offset(len(blg_forward_df), 2)).address
        xw.apps.active.macro('applyFormatForwardNumberFormat')(address)
        xw.apps.active.macro('applyFormatRightAlignment')(sheet.range('_FILL_SPOT_').address)
        xw.apps.active.macro('applyFormatRightAlignment')(sheet.range('_FILL_FORWARD_').expand('right').address)

    col = merge_df.columns.tolist().index(source)
    address = xw.Range(sheet.range('_FORWARD_').offset(0, col),
                       sheet.range('_FORWARD_').offset(len(merge_mats), col)).address
    tester1 = util.make_address(sheet.range('_FORWARD_').offset(0, 1).address, ['$', ''])
    tester2 = util.make_address(sheet.range('_FORWARD_').offset(0, col).address, ['$', ''])
    xw.apps.active.macro('applyFormatToNaBloombergForward')(address, tester1, tester2)

    xw.apps.active.screen_updating = True
    sheet.range('A1').select()
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_calculate_bloomberg_vol():
    sheet = xw.sheets.active
    sheet = go_proper_sheet(sheet, 'forward', name='_FORWARD_')

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    undcode = sheet.range('UNDCODE_').value
    source = sheet.range('SOURCE_').value
    tag = sheet.range('TAG_').value

    msg = []
    if source != 'BLOOMBERG':
        msg.append('source must be BLOOMBERG for this action')
        return '\n'.join(msg)

    args = f"""
        --date={basedt}
        -l 0
        -u {undcode}
        --action=2
        --source=BLOOMBERG
        --force_expiry 
        --tag={tag}
        --quote_type=MID,BID,ASK
        --store_db
    """.strip().split()

    opts, args = cfv.parse_command_opts(args, logger)
    cfv.calculate_forward_vol(opts)
    if source == 'BLOOMBERG':
        opts.tag = 'EOD'
        cfv.calculate_forward_vol(opts)

    msg += ['success to calculate bloomberg vol with filled forward',
            f'BASEDATE={basedt}, SOURCE=BLOOMBERG, UNDCODE={undcode}, TAG={tag}']
    xw_btn_show_bloomberg_vol()
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_show_bloomberg_vol():
    sheet = xw.sheets.active
    xw.apps.active.screen_updating = False
    sheet = go_proper_sheet(sheet, 'forward', name='_FORWARD_')
    sheet.range('_BLOOMBERG_CONTENT_ALL_').clear()

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    source = sheet.range('SOURCE_').value
    undcode = sheet.range('UNDCODE_').value
    tag = sheet.range('TAG_').value
    quote_type = 'MID'

    msg = []
    if source != 'BLOOMBERG':
        msg.append('source must be BLOOMBERG for this action')
        return '\n'.join(msg)

    ivs_df = vs.get_vols(basedt, source, undcode, tag)
    ivs_df.index = [date.to_date(e).strftime('%Y-%m-%d') for e in ivs_df.index]
    sheet.range('_BLOOMBERG_VOL_').options(index=True).value = ivs_df
    sheet.range('_BLOOMBERG_VOL_').offset(-1, 0).value = 'MID vol'
    xw.apps.active.macro('applyFormatRightAlignment')(sheet.range('_BLOOMBERG_VOL_').address)
    rng = sheet.range('_BLOOMBERG_VOL_')
    vs_address = xw.Range(rng.offset(1, 1), rng.offset(ivs_df.shape[0], ivs_df.shape[1])).address
    sheet.range(vs_address).number_format = '0.00%'

    xw.apps.active.screen_updating = True
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_adjust_bloomberg_vol():
    sheet = xw.sheets.active
    xw.apps.active.screen_updating = False
    sheet = go_proper_sheet(sheet, 'forward', name='_FORWARD_')

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    source = sheet.range('SOURCE_').value
    undcode = sheet.range('UNDCODE_').value
    tag = sheet.range('TAG_').value

    msg = []
    if source != 'BLOOMBERG':
        msg.append('source must be BLOOMBERG for this action')
        return '\n'.join(msg)

    address0 = util.split_address(sheet.range('_BLOOMBERG_VOL_').offset(0, 1).expand('right').address)
    address11 = util.split_address(sheet.range('_BLOOMBERG_VOL_').offset(1, 0).expand('down').address)
    address0[-1] = address11[-1]
    address = util.make_address(address0)
    vols = sheet.range(address).value
    expiries = sheet.range(util.make_address(address11)).value
    maturities = [date.to_date(e).strftime('%Y%m%d') for e in expiries]

    excel_ivs_df = pd.DataFrame(data=vols[1:], index=maturities, columns=vols[0])
    msg_ = vs.save_bloomberg_vol(basedt, undcode, tag, excel_ivs_df)
    msg.append(msg_)

    xw.apps.active.screen_updating = True
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_plot_bloomberg_slice(near_forward=False):
    sheet = xw.sheets.active
    sheet = go_proper_sheet(sheet, 'forward', name='_FORWARD_')
    xw.apps.active.screen_updating = False

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    source = sheet.range('SOURCE_').value
    undcode = sheet.range('UNDCODE_').value
    tag = sheet.range('TAG_').value

    msg = []
    if source != 'BLOOMBERG':
        msg.append('source must be BLOOMBERG for this action')
        return '\n'.join(msg)

    blg_df = vs.get_vols(basedt, 'BLOOMBERG', undcode, tag=tag, query_df=True)
    blg_mid_df = blg_df.pivot(index='MATURITY', columns='STRIKE', values='MID')

    forward_df, spot = vs.get_forwards(basedt, source, undcode, tag)
    forward_df = util.inner_join_keys(blg_mid_df.index.values, forward_df)
    blg_mid_df.index = [date.to_date(e).strftime('%Y-%m-%d') for e in blg_mid_df.index]

    xw.sheets['plot'].activate()
    sheet = xw.sheets.active
    pictures = list(sheet.pictures)
    for pic in pictures:
        pic.delete()

    pic_pos = []
    pos = 1
    for i in range(20):
        pic_pos.append(f'A{pos}')
        pic_pos.append(f'R{pos}')
        pos += 46

    import matplotlib.pyplot as plt
    # Turn interactive plotting off
    plt.ioff()

    fig, ax = plt.subplots(1, 1, figsize=(15, 7), gridspec_kw={'width_ratios': [1]})
    for index, s in blg_mid_df.iterrows():
        ax.plot(s, '--', label=f'{index}')
    ax.legend(loc='best')
    ax.set_title(f'{source} basedate={basedt}, und={undcode}, tag={tag}')
    sheet.pictures.add(fig, name='plot_bloomberg', update=True,
                       left=sheet.range(pic_pos[0]).left, top=sheet.range(pic_pos[0]).top)
    plt.close(fig)
    pic_pos = pic_pos[2:]

    # slice by slice plot
    for i in range(len(blg_mid_df))[:]:
        forward = forward_df['FORWARD'].iloc[i]
        fig, ax = plt.subplots(1, 1, figsize=(9, 7))
        s = blg_mid_df.iloc[i]
        if near_forward:
            s = s[(forward*0.9 < s.index) & (s.index < forward*1.1)]
            ax.set_xlim(forward*0.9, forward*1.1)
        ax.plot(s, '+', label=f'BLG MID')
        if not all(pd.isnull(s)):
            y_min, y_max = ax.get_ylim()
            ax.vlines(forward, y_min*1.1, y_max*0.85, color='black', lw=1)
            ax.annotate(f'forward({forward:.2f}, F/S:{forward / spot:.3f})',
                           xy=(forward, y_max*0.85), xytext=(forward*1.02, y_max*0.90),
                        arrowprops=dict(facecolor='black'))
            ax.legend(loc='best')
        ax.set_title(f'{basedt}_{undcode}_{source}_'
                        f'Maturity:{forward_df["MATURITY"].iloc[i]}')
        logger.debug(f'plot {basedt}_{undcode}_{source}_'
                     f'Maturity:{forward_df["MATURITY"].iloc[i]}')
        sheet.pictures.add(fig, name=f'plot_fitted_{i}', update=True,
                           left=sheet.range(pic_pos[i]).left, top=sheet.range(pic_pos[i]).top)
        # plt.show()
        # return
        plt.close(fig)
    return '\n'.join(msg)
    xw.apps.active.screen_updating = True
    sheet.range('A1').select()
    return '\n'.join(msg)


def write_compare_parameters(sheet, base_dic, target_dic, maturity_rule):
    # set value
    sheet.range('_BASE_FORWARD_').value = base_dic['spot']
    sheet.range('_BASE_FORWARD_').offset(1, 0).options(index=False, header=False).value = \
        base_dic['forward_df'][['FORWARD', 'EXPIRY']]
    sheet.range('_BASE_VOLSURFACE_').offset(0, 0).options(index=False).value = base_dic['ivs_df']

    sheet.range('_TARGET_FORWARD_').value = target_dic['spot']
    sheet.range('_TARGET_FORWARD_').offset(1, 0).options(index=False, header=False).value = \
        target_dic['forward_df'][['FORWARD', 'EXPIRY']]
    sheet.range('_TARGET_VOLSURFACE_').offset(0, 0).options(index=False).value = target_dic['ivs_df']

    sheet.range('_COMPARE_FORWARD_').value = base_dic['spot'] - target_dic['spot']
    sheet.range('_COMPARE_FORWARD_').offset(1, 0).options(index=False, header=False).value = \
        base_dic['forward_df'][['FORWARD', 'EXPIRY']]
    sheet.range('_COMPARE_FORWARD_').offset(1, 0).options(index=False, header=False).value = \
        base_dic['forward_df'].FORWARD - target_dic['forward_df'].FORWARD
    diff_vs_df = base_dic['ivs_df'] - target_dic['ivs_df']
    sheet.range('_COMPARE_VOLSURFACE_').offset(0, 0).options(index=False).value = diff_vs_df

    # set maturity
    if maturity_rule in [conf.MaturityRule.Fixed_Maturity, conf.MaturityRule.Excel_Maturity]:
        mats = base_dic['mats']
        mats = np.array(mats).reshape(len(mats), 1).tolist()
        sheet.range('_BASE_FORWARD_').offset(1, 1).value = mats
        sheet.range('_TARGET_FORWARD_').offset(1, 1).value = mats
        sheet.range('_COMPARE_FORWARD_').offset(1, 1).value = mats
        rng = sheet.range('_BASE_FORWARD_').offset(1, 1)
        address = xw.Range(rng, rng.offset(100, 0)).address
        xw.apps.active.macro('applyFormatCenterAlignment')(address)

    # set format
    rng = sheet.range('_BASE_VOLSURFACE_')
    vs_address = xw.Range(rng.offset(1, 0),
                          rng.offset(base_dic['ivs_df'].shape[0], base_dic['ivs_df'].shape[1]-1)).address
    sheet.range(vs_address).number_format = '0.00%'
    rng = sheet.range('_TARGET_VOLSURFACE_')
    vs_address = xw.Range(rng.offset(1, 0),
                          rng.offset(base_dic['ivs_df'].shape[0], base_dic['ivs_df'].shape[1]-1)).address
    sheet.range(vs_address).number_format = '0.00%'
    rng = sheet.range('_COMPARE_VOLSURFACE_')
    vs_address = xw.Range(rng.offset(1, 0),
                          rng.offset(base_dic['ivs_df'].shape[0], base_dic['ivs_df'].shape[1]-1)).address
    sheet.range(vs_address).number_format = '0.00%'
    xw.apps.active.macro('applyFormatToDiffVols')(vs_address)

    # set formula
    rng = sheet.range('_COMPARE_FORWARD_')
    address = xw.Range(rng, rng.offset(base_dic['forward_df'].shape[0] - 1, 0)).address
    formula = '=IF(OR(ISBLANK({base}), ISBLANK({target})), "", {base}-{target})'
    sheet.range(address).formula = \
        formula.format(base=sheet.range('_BASE_FORWARD_').address.replace('$', ''),
                       target=sheet.range('_TARGET_FORWARD_').address.replace('$', ''))

    formula = "={base}-{target}"
    if any(pd.isnull(diff_vs_df.iloc[0])):
        formula = '=IF(OR(ISBLANK({base}), ISBLANK({target})), "", {base}-{target})'
    sheet.range(vs_address).formula = \
        formula.format(base=sheet.range('_BASE_VOLSURFACE_').offset(1, 0).address.replace('$', ''),
                       target=sheet.range('_TARGET_VOLSURFACE_').offset(1, 0).address.replace('$', ''))

    rng = sheet.range('_BASE_FORWARD_')
    address = xw.Range(rng, rng.offset(200, 0)).address
    sheet.range(address).number_format = '0.00'


def compare_data_and_write_in_fit_sheet(sheet, ribbon_compare, strikes, forward_df, params_df,
                                        raw_forward_df, raw_ivs_df,
                                        basedt, source, undcode, tag, prevdt):
    msg = []
    compare_msg = ''
    if params_df is None:
        return
    prefix = 'ORG'
    if ribbon_compare == RibbonCompare.Compare_with_raw_data:
        compare_msg = f'compare with raw data'
        raw_forward_df2 = util.inner_join_keys(forward_df.MATURITY.values, raw_forward_df)
        compare_forward_df = forward_df[['EXPIRY', 'FORWARD']] - raw_forward_df2[['EXPIRY', 'FORWARD']]
        compare_date_df = forward_df[['MATURITY']]
        compare_date_df['EXPIRY'] = [date.to_date(e).strftime('%Y-%m-%d') for e in compare_date_df['MATURITY'].values]
        compare_forward_df['EXPIRY'] = compare_date_df['EXPIRY']
        compare_forward_df = compare_forward_df[['EXPIRY', 'FORWARD']]
        compare_forward_df.columns = ['', 'FORWARD']
        ivs_df = vs.ivs_by_parameters(forward_df, strikes, params_df)
        raw_ivs_df2 = util.inner_join_keys(forward_df.MATURITY.values, raw_ivs_df)
        raw_ivs_df2.index = [date.to_datetime(e) for e in raw_ivs_df2.index.values]
        compare_ivs_df = ivs_df - raw_ivs_df2
        target_maturities = raw_forward_df['MATURITY'].values

    elif ribbon_compare == RibbonCompare.Compare_with_prev_data:
        ivs_df = vs.ivs_by_parameters(forward_df, strikes, params_df)
        if not prevdt:
            prevdt = md.get_recentdt_of_param_table(basedt, source, undcode, tag, conf.SVI_PARAMETERS[0])
        if not prevdt:
            msg.append('There is no prev fitted data for 30 days')
            return '\n'.join(msg)
        compare_msg = f"compare with prev fitted data {date.to_date(prevdt).strftime('%Y-%m-%d')}  "
        prev_params_df = vs.get_params(prevdt, source, undcode, tag)
        prev_forward_df, _ = vs.get_forwards(prevdt, source, undcode, tag)

        prev_ivs_df = vs.ivs_by_parameters(prev_forward_df, strikes, prev_params_df)
        compare_forward_df = forward_df[['EXPIRY', 'FORWARD']] - prev_forward_df[['EXPIRY', 'FORWARD']]
        compare_date_df = forward_df[['MATURITY']]
        compare_date_df['EXPIRY'] = [date.to_date(e).strftime('%Y-%m-%d') for e in compare_date_df['MATURITY'].values]
        compare_forward_df['EXPIRY'] = compare_date_df['EXPIRY']
        compare_forward_df = compare_forward_df[['EXPIRY', 'FORWARD']]
        compare_forward_df.columns = ['', 'FORWARD']
        compare_ivs_df = ivs_df - prev_ivs_df

        params_df = sc.SVI_JW.convert_params_original_to_trader(params_df)
        params_df = params_df.where(pd.notnull(params_df), 0)
        prev_params_df = sc.SVI_JW.convert_params_original_to_trader(prev_params_df)
        prev_params_df = prev_params_df.where(pd.notnull(prev_params_df), 0)
        compare_params_df = params_df - prev_params_df
        compare_params_df.columns = [e.replace('JW_', '') for e in compare_params_df.columns]

        prefix = 'TARGET'
        sheet.range('_TARGET_LABEL_').value = 'prev fitted ivs'
        target_maturities = prev_forward_df['MATURITY'].values
        prev_forward_df = prev_forward_df[['EXPIRY', 'FORWARD']]
        prev_forward_df.columns = ['', 'FORWARD']
        sheet.range('_TARGET_FORWARD_').options(index=False).value = prev_forward_df
        sheet.range('_TARGET_VOLSURFACE_').options(index=False).value = prev_ivs_df
        sheet.range('_TARGET_PARAMETER_').options(index=False).value = prev_params_df
        sheet.range('_TARGET_PARAMETER_').offset(1, 0).expand('down').number_format = '0.00%'
        sheet.range('_TARGET_PARAMETER_').offset(1, 4).expand('down').number_format = '0.00%'
        address = sheet.range('_TARGET_VOLSURFACE_').offset(1, 0).expand().address
        sheet.range(address).number_format = '0.00%'

    sheet.range('_COMPARE_MSG_').value = compare_msg
    sheet.range('_COMPARE_FORWARD_').options(index=False).value = compare_forward_df
    sheet.range('_COMPARE_VOLSURFACE_').options(index=False).value = compare_ivs_df

    address0 = util.split_address(sheet.range('_COMPARE_VOLSURFACE_').expand('right').offset(1, 0).address)
    address11 = util.split_address(sheet.range('_COMPARE_FORWARD_').expand('down').address)
    address0[-1] = address11[-1]
    address = util.make_address(address0)
    sheet.range(address).number_format = '0.00%'
    xw.apps.active.macro('applyFormatToDiffVols')(address)
    if ribbon_compare == RibbonCompare.Compare_with_prev_data:
        sheet.range('_COMPARE_PARAMETER_').options(index=False).value = compare_params_df
        sheet.range('_COMPARE_PARAMETER_').offset(1, 1).expand('down').number_format = '0.0000'
        sheet.range('_COMPARE_PARAMETER_').offset(1, 2).expand('down').number_format = '0.0000'
        sheet.range('_COMPARE_PARAMETER_').offset(1, 3).expand('down').number_format = '0.0000'
        rng = sheet.range('_COMPARE_PARAMETER_')
        address = xw.Range(rng.offset(1, 1), rng.offset(compare_params_df.shape[0], 3)).address
        xw.apps.active.macro('applyFormatToDiffVols')(address)

    # set formulas
    fit_maturities = forward_df['MATURITY'].values
    fit_pos = sheet.range(f'_FITTED_FORWARD_').offset(1, 1).address
    target_pos = sheet.range(f'_{prefix}_FORWARD_').offset(1, 1).address

    compare_forward_df['FORMULA'] = diff_formula(fit_maturities, fit_pos, target_maturities, target_pos, fit_maturities)
    forward_compare_pos = sheet.range('_COMPARE_FORWARD_').offset(1, 1).address
    sheet.range(forward_compare_pos).options(index=False, header=False).value = compare_forward_df['FORMULA']

    vs_compare_pos = sheet.range('_COMPARE_VOLSURFACE_').offset(1, 0).address
    fit_pos = sheet.range(f'_FITTED_VOLSURFACE_').offset(1, 0).address
    target_pos = sheet.range(f'_{prefix}_VOLSURFACE_').offset(1, 0).address
    diff_pos_list = diff_formula(fit_maturities, fit_pos, target_maturities, target_pos, fit_maturities)
    for i, formula in enumerate(diff_pos_list):
        if formula:
            sheet.range(xw.Range(vs_compare_pos).offset(i).expand('right')).formula = formula

    if ribbon_compare == RibbonCompare.Compare_with_prev_data:
        params_compare_pos = sheet.range('_COMPARE_PARAMETER_').offset(1, 0).address
        fit_pos = sheet.range(f'_FITTED_PARAMETER_').offset(1, 0).address
        target_pos = sheet.range(f'_{prefix}_PARAMETER_').offset(1, 0).address
        diff_pos_list = diff_formula(fit_maturities, fit_pos, target_maturities, target_pos, fit_maturities)
        for i, formula in enumerate(diff_pos_list):
            if formula:
                sheet.range(xw.Range(params_compare_pos).offset(i).expand('right')).formula = formula
        sheet.range('_COMPARE_PARAMETER_').offset(1, 1).expand('down').number_format = '0.0000'
        sheet.range('_COMPARE_PARAMETER_').offset(1, 2).expand('down').number_format = '0.0000'
        sheet.range('_COMPARE_PARAMETER_').offset(1, 3).expand('down').number_format = '0.0000'


def diff_formula(base_keys, base_pos, other_keys, other_pos, keys):
    diff_pos_list = []

    b_col_letter, b_row_num = util.split_address(base_pos)
    o_col_letter, o_row_num = util.split_address(other_pos)
    b_row_num = int(b_row_num)
    o_row_num = int(o_row_num)

    base_keys = list(base_keys)
    other_keys = list(other_keys)

    for key in keys:
        formula = ''
        base_offset = base_keys.index(key) if key in base_keys else None
        other_offset = other_keys.index(key) if key in other_keys else None
        if base_offset is not None and other_offset is not None:
            formula = f'={b_col_letter}{b_row_num+base_offset}-{o_col_letter}{o_row_num+other_offset}'
        diff_pos_list.append(formula)
    return diff_pos_list


@util.fd_timer
@xw.func
def xw_btn_fit_excel_data(compare):
    sheet = xw.sheets.active
    sheet = go_proper_sheet(sheet)
    sheet.range('_FITTED_PARAMETER_').expand().clear_contents()
    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    undcode = sheet.range('UNDCODE_').value
    source = sheet.range('SOURCE_').value
    tag = sheet.range('TAG_').value
    xw.apps.active.screen_updating = False

    ribbon_compare = RibbonCompare(int(compare))
    calibrate_type = sheet.range('CALIBRATE_TYPE_').value
    if not calibrate_type:
        calibrate_type = 'JW'
    interpolate_fitting_parameter = conf.InterpolateFittingParameter(
        get_sw_value(sheet.range('INTERPOLATE_FITTING_PARAMETER_').value, 'SW_INTERPOLATE_FITTING_PARAMETER_LIST'))

    msg = []
    try:
        vol_tu = load_excel_info(sheet, basedt, source, undcode, tag)
    except Exception as e:
        msg.append(str(e))
        return '\n'.join(msg)
    params_df = vs.svi_calibrate(vol_tu.fit_info_df, vol_tu.skews,
                                 calibrate_type=calibrate_type,
                                 inits=None, method='SLSQP',
                                 interpolate_fitting_parameter=interpolate_fitting_parameter,
                                 strikes=vol_tu.strikes)

    fitted_forward_df = vol_tu.fit_info_df[vol_tu.forward_df.columns]
    ivs_df = vs.ivs_by_parameters(fitted_forward_df, vol_tu.strikes, params_df, column_to_str=True)
    # if sheet.range('_FITTED_SPOT_').value:
    #     sheet.range('_FITTED_PARAMETER_').expand().clear_contents()
    #     write_just_fit_parameters(sheet, params_df)
    # else:
    write_load_data(sheet, vol_tu, params_df, ivs_df)

    if params_df is not None and ribbon_compare > 0:
        compare_msg = sheet.range('_COMPARE_MSG_').value
        if compare_msg and ((ribbon_compare == RibbonCompare.Compare_with_prev_data and 'prev' in compare_msg)
                            or (ribbon_compare == RibbonCompare.Compare_with_raw_data and 'raw' in compare_msg)):
            # do not compare if diff formula is already written.
            return
        sheet.range('_COMPARE_CONTENT_ALL_').clear()
        _msg = compare_data_and_write_in_fit_sheet(sheet, ribbon_compare, vol_tu.strikes, vol_tu.forward_df, params_df,
                                                   vol_tu.raw_forward_df, vol_tu.raw_ivs_df,
                                                   basedt, source, undcode, tag, None)
        if _msg:
            msg.append(_msg)
    xw.apps.active.screen_updating = True
    sheet.range('_ORG_FORWARD_').select()
    return '\n'.join(msg)


def get_sw_value(value, sw_name, col=1):
    sw = xw.Range(xw.Range(sw_name), xw.Range(sw_name).offset(0, col)).value
    res = None
    for e in sw:
        if e[0] == value:
            res = e[col]
            break
    return res


def load_excel_info(sheet, basedt, source, undcode, tag) -> vs.VolTu:
    """
    ref volsurface.load_info function
    """
    raw_spot = sheet.range('_ORG_SPOT_').value
    spot = sheet.range('_FITTED_SPOT_').value

    res = dict()
    res['basedate'] = date.to_datetime(basedt)
    res['raw_spot'] = raw_spot
    res['spot'] = spot
    is_existed_fit_data = True
    if not spot:
        is_existed_fit_data = False
        res['spot'] = raw_spot
    if not is_existed_fit_data:
        raise Exception(f'there is no forward for fitting with tag {tag}')
    raw_expiries = sheet.range('_ORG_FORWARD_').expand('down').value
    raw_forwards = sheet.range('_ORG_FORWARD_').offset(column_offset=1).expand('down').value
    zips = list(zip(raw_expiries, raw_forwards))
    raw_forward_df = pd.DataFrame(data=zips[1:], columns=['EXPIRY', 'FORWARD'])
    raw_forward_df['MATURITY'] = [date.to_date(e).strftime('%Y%m%d') for e in raw_forward_df['EXPIRY'].values]
    res['raw_forward_df'] = raw_forward_df

    if is_existed_fit_data:
        forwards = xw.Range(sheet.range('_FITTED_FORWARD_').offset(1, 0),
                            sheet.range('_FITTED_FORWARD_').offset(1, 1)).expand('down').value
        forward_df = pd.DataFrame(data=forwards, columns=['EXPIRY', 'FORWARD'])
    else:
        forward_df = raw_forward_df.copy(deep=True)
    forward_df['MATURITY'] = [date.to_date(e).strftime('%Y%m%d') for e in forward_df['EXPIRY'].values]
    forward_df['YEARFRAC'] = [date.yearfrac(basedt, e) for e in forward_df['MATURITY'].values]

    res['forward_df'] = forward_df

    # because values of cell can be None, address need to be made up
    address0 = util.split_address(sheet.range('_ORG_VOLSURFACE_').expand('right').address)
    address11 = util.split_address(sheet.range('_ORG_FORWARD_').expand('down').address)
    address0[-1] = address11[-1]
    address = util.make_address(address0)
    vols = sheet.range(address).value
    raw_ivs_df = pd.DataFrame(data=vols[1:], index=raw_forward_df['MATURITY'], columns=vols[0])
    res['raw_ivs_df'] = raw_ivs_df

    raw_ivs_df2 = res['raw_ivs_df'].copy(deep=True)
    raw_ivs_df2.insert(loc=0, column='EXPIRY', value=pd.to_datetime(raw_ivs_df2.index.values))
    fit_info_df, skews, strikes, msg = vs.make_fit_info_with_ysk_expiries(basedt, undcode, source, tag,
                                                                          raw_ivs_df2,
                                                                          res['forward_df'], conf.FFillMethod(0))
    res['fit_info_df'] = fit_info_df
    res['skews'] = skews
    target_strikes = conf.target_strikes(undcode, res['spot'], False)
    res['strikes'] = target_strikes
    return vs.VolTu(**res)


@util.fd_timer
@xw.func
def xw_btn_save_parameters():
    sheet = xw.sheets.active
    sheet = go_proper_sheet(sheet)
    xw.apps.active.screen_updating = False

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    undcode = sheet.range('UNDCODE_').value
    source = sheet.range('SOURCE_').value
    spot = sheet.range('_FITTED_SPOT_').value
    forwards = xw.Range(sheet.range('_FITTED_FORWARD_').offset(1, 0),
                        sheet.range('_FITTED_FORWARD_').offset(1, 1)).expand('down').value
    forward_df = pd.DataFrame(data=forwards, columns=['EXPIRY', 'FORWARD'])
    forward_df['MATURITY'] = forward_df['EXPIRY'].dt.strftime('%Y%m%d')
    params = sheet.range('_FITTED_PARAMETER_').expand().value
    tag = sheet.range('TAG_').value

    params_df = pd.DataFrame(data=params[1:], index=forward_df['MATURITY'], columns=params[0])
    params_df.columns = conf.SVI_PARAMETERS
    params_df = sc.SVI_JW.convert_params_trader_to_original(params_df)
    logger.debug(params_df)
    msg = []
    # skip maturities in which forward values are np.nan.
    if any(np.isnan(forward_df.FORWARD)):
        msg.append('skip to save parameters at maturities in which forward values are np.nan.')
    forward_df = forward_df[~np.isnan(forward_df.FORWARD)]
    params_df = util.inner_join_keys(forward_df.MATURITY.values, params_df)

    if tag == 'EOD':
        raise Exception("tag can't be EOD in fitting sheet.")
    vs.save_parameters(basedt, source, undcode, tag, spot, forward_df, params_df, save_forward=False, save_params=True)
    msg += ['success to save parameters', f'BASEDATE={basedt}, SOURCE={source}, UNDCODE={undcode}',
            f'TAG={tag}']
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_delete_parameters():
    sheet = xw.sheets.active
    sheet = go_proper_sheet(sheet)
    xw.apps.active.screen_updating = False

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    undcode = sheet.range('UNDCODE_').value
    source = sheet.range('SOURCE_').value
    tag = sheet.range('TAG_').value

    vs.delete_parameters(basedt, source, undcode, tag)
    msg = ['success to delete parameters.', f'BASEDATE={basedt}, SOURCE={source}, UNDCODE={undcode}',
           f'TAG={tag}']
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_ah_load_iv():
    sheet = xw.sheets.active
    xw.apps.active.screen_updating = False
    sheet = go_proper_sheet(sheet, 'AH_Interp', name='SHEET_AH_')
    sheet.range('_CONTENT_ALL_').clear()

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    source = sheet.range('SOURCE_').value
    undcode = sheet.range('UNDCODE_').value
    tag = sheet.range('TAG_').value

    msg = []
    res = vs.load_iv(basedt, source, undcode, tag)
    if not res['data']:
        msg.append('there is no iv')
        return '\n'.join(msg)

    # set value
    sheet.range('_FORWARD_').value = res['spot']
    sheet.range('_FORWARD_').offset(1, 0).options(index=False, header=False).value = \
        res['forward_df'][['FORWARD', 'EXPIRY']]
    sheet.range('_VOLSURFACE_').offset(0, 0).options(index=False).value = res['ivs_df']

    # set format
    rng = sheet.range('_VOLSURFACE_')
    vs_address = xw.Range(rng.offset(1, 0),
                          rng.offset(res['ivs_df'].shape[0], res['ivs_df'].shape[1]-1)).address
    sheet.range(vs_address).number_format = '0.00%'
    rng = sheet.range('_FORWARD_')
    address = xw.Range(rng, rng.offset(200, 0)).address
    sheet.range(address).number_format = '0.00'

    xw.apps.active.screen_updating = True
    sheet.range('A1').select()
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_ah_interpolate():
    sheet = xw.sheets.active
    xw.apps.active.screen_updating = False
    sheet = go_proper_sheet(sheet, 'AH_Interp', name='SHEET_AH_')
    sheet.range('_CONTENT_ALL_AH_').clear()

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    source = sheet.range('SOURCE_').value
    undcode = sheet.range('UNDCODE_').value
    tag = sheet.range('TAG_').value
    interp_target = conf.AHInterpTarget(
        get_sw_value(sheet.range('INTERPOLATE_TARGET_').value, 'SW_INTERPOLATE_TARGET_LIST'))

    msg = []
    spot = sheet.range('_FORWARD_').value
    is_existed_data = True if spot else False
    if not is_existed_data:
        msg.append('there is no iv')
        return '\n'.join(msg)
    forwards = xw.Range(sheet.range('_FORWARD_').offset(1, 0),
                        sheet.range('_FORWARD_').offset(1, 1)).expand('down').value
    forward_df = pd.DataFrame(data=forwards, columns=['FORWARD', 'EXPIRY'])
    forward_df['MATURITY'] = [date.to_date(e).strftime('%Y%m%d') for e in forward_df['EXPIRY'].values]
    forward_df['YEARFRAC'] = [date.yearfrac(basedt, e) for e in forward_df['MATURITY'].values]
    forward_df.index = forward_df['MATURITY'].values

    address = util.get_address(sheet, '_VOLSURFACE_')
    vols = sheet.range(address).value
    ivs_df = pd.DataFrame(data=vols[1:], index=forward_df['MATURITY'], columns=vols[0])

    forward = md.Forward().load_from_db(basedt, source, undcode, tag)
    forward_df = forward.get_forward_df()
    slice_num = 100
    forward_df = forward_df[:slice_num]
    ah = ac.AndreasenHuge(basedt, forward, ivs_df, mesh_k_num=301, interp_target=interp_target, slice_num=slice_num)
    ah.interp()
    proxy_df = ah.get_proxy()
    ah_iv_df = ah.get_iv_surface()
    diff_iv_df = ah_iv_df - ivs_df

    proxy_df.index = forward_df['EXPIRY'].values
    ah_iv_df.index = forward_df['EXPIRY'].values
    diff_iv_df.index = forward_df['EXPIRY'].values

    sheet.range('_VOLPROXY_').offset(0, 0).options(index=True).value = proxy_df
    sheet.range('_AH_IV_').offset(0, 0).options(index=True).value = ah_iv_df
    sheet.range('_DIFF_IV_').offset(0, 0).options(index=True).value = diff_iv_df

    # set format
    rng = sheet.range('_VOLPROXY_')
    address = xw.Range(rng.offset(1, 1),
                       rng.offset(proxy_df.shape[0], proxy_df.shape[1])).address
    sheet.range(address).number_format = '0.00'
    xw.apps.active.macro('applyFormatToDiffVols')(address)
    rng = sheet.range('_AH_IV_')
    address = xw.Range(rng.offset(1, 1),
                       rng.offset(ah_iv_df.shape[0], ah_iv_df.shape[1])).address
    sheet.range(address).number_format = '0.00%'
    rng = sheet.range('_DIFF_IV_')
    address = xw.Range(rng.offset(1, 1),
                       rng.offset(diff_iv_df.shape[0], diff_iv_df.shape[1])).address
    sheet.range(address).number_format = '0.00%'
    xw.apps.active.macro('applyFormatToDiffVols')(address)

    xw.apps.active.screen_updating = True
    sheet.range('A1').select()
    return '\n'.join(msg)


def go_proper_sheet(sheet, sheetname='fit', name='_FITTED_FORWARD_'):
    try:
        _ = sheet.range(name).value
        logger.info(f"activesheet name is '{sheet.name}'")
    except Exception as e:
        logger.warning(f"'{sheet.name}' sheet isn't proper sheet for current action. activate '{sheetname}' sheet")
        xw.sheets[sheetname].activate()
        sheet = xw.sheets.active
    return sheet


def set_fit_sheet_args_to_compare_sheet(sheet, sheetname='compare', name='_FITTED_FORWARD_'):
    try:
        _ = sheet.range(name).value
        logger.info(f"activesheet name is '{sheet.name}'. this sheet is fit sheet.")
        logger.info(f"set fit sheet arguments to compare sheet")
        xw.sheets[sheetname].range('BASE_DATE_').value = sheet.range('BASEDATE_').value
        xw.sheets[sheetname].range('BASE_SOURCE_').value = sheet.range('SOURCE_').value
        xw.sheets[sheetname].range('BASE_UNDCODE_').value = sheet.range('UNDCODE_').value
        xw.sheets[sheetname].range('BASE_TAG_').value = sheet.range('TAG_').value

        xw.sheets[sheetname].range('TARGET_DATE_').value = sheet.range('BASEDATE_').value
        xw.sheets[sheetname].range('TARGET_SOURCE_').value = sheet.range('SOURCE_').value
        xw.sheets[sheetname].range('TARGET_UNDCODE_').value = sheet.range('UNDCODE_').value
        xw.sheets[sheetname].range('TARGET_TAG_').value = 'EOD'

        xw.sheets[sheetname].range('COMPARE_STRIKE_RULE_').value = ''
    except Exception as e:
        logger.info(f"activesheet name is '{sheet.name}'. this sheet isn't fit sheet.")
    return sheet
    pass


@util.fd_timer
@xw.func
def xw_btn_plot_fit_data(slice_num=100):
    sheet = xw.sheets.active
    sheet = go_proper_sheet(sheet)
    xw.apps.active.screen_updating = False
    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    spot = sheet.range('_ORG_SPOT_').value
    source = sheet.range('SOURCE_').value
    undcode = sheet.range('UNDCODE_').value
    tag = sheet.range('TAG_').value

    msg = []
    vol_tu = load_excel_info(sheet, basedt, source, undcode, tag)
    expiries = sheet.range('_FITTED_FORWARD_').expand('down').value
    params = sheet.range('_FITTED_PARAMETER_').expand().value
    if not params:
        msg.append('there are no fit parameters.')
        return '\n'.join(msg)
    params_df = pd.DataFrame(data=params[1:], index=expiries[1:], columns=params[0])
    params_df.columns = conf.SVI_PARAMETERS
    params_df = sc.SVI_JW.convert_params_trader_to_original(params_df)
    ivs_df = vs.ivs_by_parameters(vol_tu.forward_df, vol_tu.strikes, params_df)
    params_df['EXPIRY'] = params_df.index.values
    params_df['MATURITY'] = params_df['EXPIRY'].dt.strftime('%Y-%m-%d')
    params_df['MASK'] = ''
    full_maturities = params_df['MATURITY'].values

    # corresponding to fitted maturities, plot original and fitted slices
    ivs_df.index = ivs_df.index.strftime('%Y-%m-%d')
    raw_ivs_df = vol_tu.raw_ivs_df.copy(deep=True)
    raw_ivs_df.index = [date.to_date(e).strftime('%Y-%m-%d') for e in vol_tu.raw_ivs_df.index]
    raw_ivs_df = util.outer_join_keys(full_maturities, raw_ivs_df)

    compare_strikes = np.array(raw_ivs_df.columns.values[:], dtype=float)
    compare_ivs_df = vs.ivs_by_parameters(vol_tu.forward_df, compare_strikes, params_df[conf.SVI_PARAMETERS])
    compare_ivs_df.index = compare_ivs_df.index.strftime('%Y-%m-%d')
    compare_ivs_df = util.outer_join_keys(full_maturities, compare_ivs_df)
    compare_df = compare_ivs_df - raw_ivs_df

    blg_df = vs.get_vols(basedt, 'BLOOMBERG', undcode, query_df=True)
    blg_bid_df = blg_df.pivot(index='MATURITY', columns='STRIKE', values='BID')
    blg_mid_df = blg_df.pivot(index='MATURITY', columns='STRIKE', values='MID')
    blg_ask_df = blg_df.pivot(index='MATURITY', columns='STRIKE', values='ASK')
    blg_bid_df.index = [date.to_date(e).strftime('%Y-%m-%d') for e in blg_bid_df.index]
    blg_mid_df.index = [date.to_date(e).strftime('%Y-%m-%d') for e in blg_mid_df.index]
    blg_ask_df.index = [date.to_date(e).strftime('%Y-%m-%d') for e in blg_ask_df.index]
    blg_bid_df = util.outer_join_keys(full_maturities, blg_bid_df)
    blg_mid_df = util.outer_join_keys(full_maturities, blg_mid_df)
    blg_ask_df = util.outer_join_keys(full_maturities, blg_ask_df)
    ask_bid_df = blg_ask_df - blg_bid_df

    xw.sheets['plot'].activate()
    sheet = xw.sheets.active
    pictures = list(sheet.pictures)
    for pic in pictures:
        pic.delete()

    pic_pos = []
    pos = 1
    for i in range(20):
        pic_pos.append(f'A{pos}')
        pic_pos.append(f'R{pos}')
        pos += 46

    import matplotlib.pyplot as plt
    # Turn interactive plotting off
    plt.ioff()

    fig, ax = plt.subplots(1, 2, figsize=(20, 7), gridspec_kw={'width_ratios': [1, 1]})
    for i in range(len(vol_tu.forward_df['FORWARD'])):
        if all(pd.isnull(raw_ivs_df.iloc[i].values)):
            params_df['MASK'].iloc[i] = '*'
        else:
            ax[0].plot(raw_ivs_df.iloc[i], '--', label=f'{raw_ivs_df.index[i]}')
        ax[1].plot(ivs_df.iloc[i], '-', label=f"{ivs_df.index[i]}{params_df['MASK'].iloc[i]}")
    ax[0].legend(loc='best')
    ax[0].set_title(f'{source}')
    ax[1].legend(loc='best')
    ax[1].set_title(f'fitted')
    sheet.pictures.add(fig, name='plot_original_fitted', update=True,
                       left=sheet.range(pic_pos[0]).left, top=sheet.range(pic_pos[0]).top)
    plt.close(fig)
    pic_pos = pic_pos[2:]

    # check butterfly arbitrage
    g_vars = vs.g_var_by_parameters(vol_tu.forward_df, params_df[conf.SVI_PARAMETERS])
    fig, ax = plt.subplots(1, 2, figsize=(20, 7), gridspec_kw={'width_ratios': [1, 1]})
    for i in range(len(g_vars)):
        ax[0].plot(g_vars[i][1], '-', label=f"{params_df['MATURITY'].iloc[i]}{params_df['MASK'].iloc[i]}")
        ax[1].plot(np.exp(g_vars[i][0].index), g_vars[i][0].values, '-',
                   label=f"{params_df['MATURITY'].iloc[i]}{params_df['MASK'].iloc[i]}")
        ax[1].hlines(0, 0, np.max(np.exp(g_vars[i][0].index)), color='black', lw=0.5)
    ax[0].legend(loc='best')
    ax[0].set_title(f'total variance')
    ax[0].set_xlabel('ln(k/f)')
    ax[1].legend(loc='best')
    ax[1].set_title(f'g')
    ax[1].set_xlabel('k/f')
    sheet.pictures.add(fig, name='g_fitted', update=True,
                       left=sheet.range(pic_pos[0]).left, top=sheet.range(pic_pos[0]).top)
    plt.close(fig)
    pic_pos = pic_pos[2:]

    # slice by slice plot
    for i in range(len(vol_tu.forward_df['FORWARD'][:slice_num])):
        forward = vol_tu.forward_df['FORWARD'].iloc[i]
        fig, ax = plt.subplots(2, 1, figsize=(9, 7), gridspec_kw={'height_ratios': [4, 1]})
        ax[0].plot(ivs_df.iloc[i], '-', label='fitted')
        ax[0].plot(raw_ivs_df.iloc[i], 'o', label=f'{source}')
        ax[0].plot(blg_bid_df.iloc[i], '+', label=f'BLG BID')
        ax[0].plot(blg_ask_df.iloc[i], '+', label=f'BLG ASK')
        y_min, y_max = ax[0].get_ylim()
        ax[0].vlines(forward, y_min*1.1, y_max*0.85, color='black', lw=1)
        ax[0].vlines(spot, y_min*1.1, y_max*0.8, color='royalblue', lw=1)
        ax[0].annotate(f'forward({forward:.2f}, F/S:{forward / spot:.3f})',
                       xy=(forward, y_max*0.85), xytext=(forward*1.05, y_max*0.91), arrowprops=dict(facecolor='black'))
        ax[0].annotate(f'spot({spot})',
                       xy=(spot, y_max*0.8), xytext=(spot*1.05, y_max*0.85), arrowprops=dict(facecolor='royalblue'))
        ax[0].legend(loc='best')
        ax[0].set_title(f'{basedt}_{undcode}_{source}_'
                        f'Maturity:{params_df["MATURITY"].iloc[i]}{params_df["MASK"].iloc[i]}')
        logger.debug(f'plot {basedt}_{undcode}_{source}_'
                     f'Maturity:{params_df["MATURITY"].iloc[i]}{params_df["MASK"].iloc[i]}')

        ax[1].plot(compare_df.iloc[i], '+', color='C0', lw=1)
        # ax[1].axhline(color='C0', lw=0.5)
        ax[1].set_ylabel(f'fitted-{source}')
        ax[1].grid(True)
        ax[1].set_xlabel('diff')
        if True:
            # instantiate a second axis that shares the same x-axis
            ax_twin = ax[1].twinx()
            ax_twin.set_ylabel(f'ask-bid')
        else:
            ax_twin = ax[1]
        ax_twin.plot(ask_bid_df.iloc[i], '+', color='silver', lw=0.1)

        sheet.pictures.add(fig, name=f'plot_fitted_{i}', update=True,
                           left=sheet.range(pic_pos[i]).left, top=sheet.range(pic_pos[i]).top)
        plt.close(fig)
    xw.apps.active.screen_updating = True
    return '\n'.join(msg)


@util.fd_timer
@xw.func
def xw_btn_remove_graphs():
    sheet = xw.sheets.active
    xw.apps.active.screen_updating = False
    pictures = list(sheet.pictures)
    for pic in pictures:
        pic.delete()
    xw.apps.active.screen_updating = True


@xw.func
def xw_btn_just_plot():
    if True:
        xw_btn_plot_fit_data(slice_num=3)
        return

    if False:
        sheet = xw.sheets.active
        xw.apps.active.screen_updating = False

        import matplotlib.pyplot as plt
        fig = plt.figure(figsize=(5, 5))
        plt.title('test_plot')
        x = range(10)
        plt.plot(x, [(e+10, e**2) for e in x], 'o-')
        sheet.pictures.add(fig, name='MyPlot', left=sheet.range('E5').left, top=sheet.range('E5').top, update=True)
        sheet.range('A1').select()
        xw.apps.active.screen_updating = True
        return ''


def write_just_fit_parameters(sheet, params_df):
    if params_df is not None:
        trader_params_df = sc.SVI_JW.convert_params_original_to_trader(params_df)
        trader_params_df.columns = [e.replace('JW_', '') for e in trader_params_df.columns]
        trader_params_df = trader_params_df.where(pd.notnull(trader_params_df), 0)
        sheet.range('_FITTED_PARAMETER_').options(index=False).value = trader_params_df


def write_load_data(sheet, vol_tu, params_df, ivs_df):
    raw_forward_df = vol_tu.raw_forward_df.copy(deep=True)[['EXPIRY', 'FORWARD']]
    raw_forward_df.columns = ['', 'FORWARD']

    sheet.range('_ORG_SPOT_').value = vol_tu.raw_spot
    sheet.range('_ORG_FORWARD_').options(index=False).value = raw_forward_df
    sheet.range('_ORG_VOLSURFACE_').options(index=False).value = vol_tu.raw_ivs_df
    rng = sheet.range('_ORG_VOLSURFACE_')
    vs_address = xw.Range(rng.offset(1, 0), rng.offset(vol_tu.raw_ivs_df.shape[0],
                                                       vol_tu.raw_ivs_df.shape[1] - 1)).address
    sheet.range(vs_address).number_format = '0.00%'

    if vol_tu.spot:
        sheet.range('_FITTED_SPOT_').value = vol_tu.spot
        fitted_forward_df = vol_tu.forward_df[['EXPIRY', 'FORWARD']]
        fitted_forward_df.columns = ['', 'FORWARD']
        sheet.range('_FITTED_FORWARD_').options(index=False).value = fitted_forward_df

    if params_df is not None:
        trader_params_df = sc.SVI_JW.convert_params_original_to_trader(params_df)
        trader_params_df.columns = [e.replace('JW_', '') for e in trader_params_df.columns]
        trader_params_df = trader_params_df.where(pd.notnull(trader_params_df), 0)
        sheet.range('_FITTED_PARAMETER_').options(index=False).value = trader_params_df
        sheet.range('_FITTED_PARAMETER_').offset(1, 0).expand('down').number_format = '0.00%'
        sheet.range('_FITTED_PARAMETER_').offset(1, 4).expand('down').number_format = '0.00%'
        address = sheet.range('_FITTED_PARAMETER_').expand().address
        xw.apps.active.macro('applyFormatToFitParameters')(address)

        fitted_yearfrac_df = vol_tu.forward_df[['YEARFRAC']]
        sheet.range('_FITTED_YEARFRAC_').options(index=False).value = fitted_yearfrac_df

        sheet.range('_FITTED_VOLSURFACE_').options(index=False).value = ivs_df.where(pd.notnull(ivs_df), 0)
        sheet.range('_FITTED_VOLSURFACE_').offset(1, 0).expand().number_format = '0.00%'

    sheet.range('_CONTENT_ALL_FORWARD_').number_format = '0.00'
    # set_formulas
    # fitted ivs
    address = dict()
    address['fitted_ivs'] = sheet.range('_FITTED_VOLSURFACE_').offset(1, 0).expand().address
    address['jw_params'] = util.make_address(sheet.range('_FITTED_PARAMETER_').offset(1, 0).expand('right').address,
                                             ['$', ''])
    address['f'] = util.make_address(sheet.range('_FITTED_FORWARD_').offset(1, 1).address, ['$', ''])
    address['t'] = util.make_address(sheet.range('_FITTED_YEARFRAC_').offset(1, 0).address, ['$', ''])
    address['k'] = util.make_address(sheet.range('_FITTED_VOLSURFACE_').address, ['', '$'])
    # logger.debug('=JWSVIVol($AB26:$AF26,$C26,$Z26,D$25)')
    if util.is_array_address(address['jw_params']):
        sheet.range(address['fitted_ivs']).formula = (f"=JWSVIVol({address['jw_params']},"
                                                      f"{address['f']},{address['t']},{address['k']})")

    # check arbitrage
    # logger.debug('=IFERROR(CheckJWSVICalendarArbitrage(AB27:AF27, Z27, AB28:AF28, Z28), "")')
    address['check_calendar_arbitrage'] = sheet.range('_FITTED_PARAMETER_').offset(2, 0).expand('down')\
        .offset(0, 5).address
    address['prev_jw_params'] = address['jw_params']
    address['jw_params'] = util.make_address(sheet.range(address['prev_jw_params']).offset(1, 0).address, ['$', ''])
    address['prev_t'] = address['t']
    address['t'] = util.make_address(sheet.range(address['prev_t']).offset(1, 0).address, ['$', ''])
    sheet.range(address['check_calendar_arbitrage']).formula = (f'=IFERROR(CheckJWSVICalendarArbitrage('
                                                                f'{address["prev_jw_params"]}, {address["prev_t"]}, '
                                                                f'{address["jw_params"]}, {address["t"]}), "")')

    address['fit_address'] = sheet.range('_FITTED_PARAMETER_').offset(2, 0).expand().address
    if util.is_array_address(address['fit_address']):
        address['fit_address_split'] = util.split_address(address['fit_address'])
        tester = f"${address['fit_address_split'][2]}{address['fit_address_split'][1]}"
        xw.apps.active.macro('applyFormatToFitParametersWithArbitrage')(address['fit_address'], tester)


def write_texts_to_sheet(sheet, addr, texts):
    mm = pd.DataFrame([d.split('\t') for d in texts.splitlines()])
    sheet.range(addr).value = mm.values


@util.fd_timer
@xw.func
def xw_btn_template():
    sheet = xw.sheets.active
    xw.apps.active.screen_updating = False
    sheet = go_proper_sheet(sheet, 'forward', name='_FORWARD_')

    basedt = date.to_date(sheet.range('BASEDATE_').value).strftime('%Y%m%d')
    source = sheet.range('SOURCE_').value
    undcode = sheet.range('UNDCODE_').value
    tag = sheet.range('TAG_').value

    msg = ['this function is template function']
    xw.apps.active.screen_updating = True
    sheet.range('A1').select()
    return '\n'.join(msg)


if __name__ == '__main__':
    logger.info('start to debug xlwings')
    xw.serve()
