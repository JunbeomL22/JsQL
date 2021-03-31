import common.util as util
import numpy as np
import pandas as pd
import scipy.interpolate as si
import collections
import common.conf as conf
import common.date as date
from common.expiry import UnderlyingExpiry
from db.oracledb import OTCORA
from svi import svi_core as sc
from script.calculate_forward_vols import fill_na_forward

VolTu = collections.namedtuple('VolTu',
                               'basedate raw_spot raw_forward_df raw_ivs_df '
                               'spot forward_df params_df fit_info_df skews strikes',
                               defaults=[None] * 10)


def save_parameters(basedt, source, undcode, tag, spot, forward_df, params_df, save_forward=False, save_params=True):
    logger = util.get_logger()
    db = OTCORA(logger=logger)
    parameter_types = []
    if save_forward:
        parameter_types += ['SPOT', 'FORWARD', 'FORWARD_FACTOR']
        logger.info('save forward')
    if save_params:
        parameter_types += params_df.columns.tolist()
        logger.info('save svi parameters')
    parameter_types = f"""'{"', '".join(parameter_types)}'"""
    ip = util.get_ip_addr()
    sql_rows = []
    try:
        sql = (f"DELETE FROM YSK_VS_PARAM WHERE BASEDATE='{basedt}' AND SOURCE='{source}'"
               f" AND UNDCODE='{undcode}' AND TAG='{tag}' AND PARAMETER_TYPE IN ({parameter_types})")
        db.execute(sql, debug_sql=True)

        sql_fmt = ("INTO YSK_VS_PARAM(BASEDATE, SOURCE, UNDCODE, PARAMETER_TYPE, MATURITY, TAG, VALUE, IP) "
                   "VALUES ('{basedt}', '{source}', '{undcode}', '{parameter_type}', '{maturity}', '{tag}', "
                   "'{value}', '{ip}')")
        if save_forward:
            if spot:
                row = sql_fmt.format(basedt=basedt, source=source, undcode=undcode,
                                     parameter_type='SPOT', maturity=basedt, tag=tag, value=spot, ip=ip)
                sql_rows.append(row)

            sql_rows += [sql_fmt.format(basedt=basedt, source=source, undcode=undcode,
                                        parameter_type='FORWARD', maturity=e.MATURITY, tag=tag, value=e.FORWARD, ip=ip)
                         for e in forward_df.itertuples()]
            sql_rows += [sql_fmt.format(basedt=basedt, source=source, undcode=undcode,
                                        parameter_type='FORWARD_FACTOR', maturity=e.MATURITY, tag=tag,
                                        value=e.FORWARD / spot, ip=ip)
                         for e in forward_df.itertuples()]
        if save_params:
            df = params_df.unstack().reset_index(name='VALUE')
            df.columns = ['PARAMETER_TYPE', 'MATURITY', 'VALUE']
            sql_rows += [sql_fmt.format(basedt=basedt, source=source, undcode=undcode,
                                        parameter_type=e.PARAMETER_TYPE, maturity=e.MATURITY, tag=tag, value=e.VALUE, ip=ip)
                         for e in df.itertuples()]

        db.executemany(sql_rows, debug_sql=True)
    except Exception as e:
        db.rollback()
        logger.error(e)
        raise
    db.commit()


def delete_parameters(basedt, source, undcode, tag, delete_forward=False, delete_params=True):
    if tag == 'EOD':
        raise Exception("delete tag can't be EOD in fitting sheet.")

    logger = util.get_logger()
    parameter_types = []
    if delete_forward:
        parameter_types += ['SPOT', 'FORWARD', 'FORWARD_FACTOR']
        logger.info('delete forward')
    if delete_params:
        parameter_types += conf.SVI_PARAMETERS
        logger.info('delete svi parameters')
    parameter_types = f"""'{"', '".join(parameter_types)}'"""

    db = OTCORA(logger=logger)
    try:
        sql = (f"DELETE FROM YSK_VS_PARAM WHERE BASEDATE='{basedt}' AND SOURCE='{source}'"
               f" AND UNDCODE='{undcode}' AND TAG='{tag}' AND PARAMETER_TYPE IN ({parameter_types})")
        db.execute(sql, debug_sql=True)
    except Exception as e:
        db.rollback()
        logger.error(e)
        raise
    db.commit()


def choose_spot_forward(basedt, df):
    spot = None
    cnt = len(df[df.MATURITY == basedt])
    if cnt == 0:
        pass
    elif cnt == 1:
        spot = df.iloc[0]['VALUE']
    else:
        spot_df = df[(df.MATURITY == basedt) & (df.PARAMETER_TYPE == 'FORWARD')]
        spot = spot_df.iloc[0]['VALUE']
    df = df[cnt:]
    return spot, df


def get_forwards(basedt, source, undcode, tag):
    sql = (f"SELECT PARAMETER_TYPE, MATURITY, VALUE FROM YSK_VS_PARAM WHERE BASEDATE='{basedt}' AND SOURCE='{source}' "
           f"AND UNDCODE='{undcode}' AND PARAMETER_TYPE IN ('SPOT', 'FORWARD') AND TAG='{tag}' ORDER BY MATURITY ASC")
    df = OTCORA().query_df(sql)
    forward_df = None
    spot = None
    if not df.empty:
        spot, forward_df = choose_spot_forward(basedt, df)
        forward_df = forward_df[['MATURITY', 'VALUE']]
        forward_df.index = forward_df['MATURITY'].values
        forward_df.columns = ['MATURITY', 'FORWARD']
        forward_df['EXPIRY'] = pd.to_datetime(forward_df['MATURITY'])
        forward_df['YEARFRAC'] = [date.yearfrac(basedt, e) for e in forward_df['MATURITY'].values]
    return forward_df, spot


def get_params(basedt, source, undcode, tag):
    sql = (f"SELECT MATURITY, PARAMETER_TYPE, VALUE FROM YSK_VS_PARAM WHERE BASEDATE='{basedt}' AND SOURCE='{source}'"
           f" AND UNDCODE='{undcode}' AND TAG='{tag}' AND PARAMETER_TYPE LIKE 'JW%'")
    df = OTCORA().query_df(sql)
    params_df = None
    if not df.empty:
        params_df = df.pivot(index='MATURITY', columns='PARAMETER_TYPE', values='VALUE')
        params_df = params_df[conf.SVI_PARAMETERS]
    return params_df


def get_vols(basedt, source, undcode, tag='EOD', column_type=None, query_df=False):
    sql = (f"SELECT MATURITY, STRIKE, BID, MID, ASK FROM YSK_VS_VOL WHERE BASEDATE='{basedt}' AND SOURCE='{source}'"
           f"AND UNDCODE='{undcode}' AND TAG='{tag}' ORDER BY MATURITY ASC, STRIKE ASC")
    df = OTCORA().query_df(sql)
    if query_df:
        return df
    res_df = None
    ivs_df = df.pivot(index='MATURITY', columns='STRIKE', values='MID')
    if not ivs_df.empty:
        if column_type == 'str':
            ivs_df.columns = util.ndarray_to_list(ivs_df.columns.values, True)
        res_df = ivs_df
    return res_df


def load_info(basedt, source, undcode, tag) -> VolTu:
    res = dict()
    res['basedate'] = pd.to_datetime(basedt).to_pydatetime()
    res['raw_forward_df'], res['raw_spot'] = get_forwards(basedt, source, undcode, 'EOD')
    res['raw_ivs_df'] = get_vols(basedt, source, undcode, 'EOD')

    forward_df, spot = get_forwards(basedt, source, undcode, tag)
    res['forward_df'] = forward_df
    res['spot'] = spot
    res['params_df'] = get_params(basedt, source, undcode, tag)
    if res['params_df'] is not None:
        raw_ivs_df2 = util.outer_join_keys(forward_df['MATURITY'].values, res['raw_ivs_df'])
        raw_ivs_df2.insert(loc=0, column='EXPIRY', value=pd.to_datetime(raw_ivs_df2.index.values))
        fit_info_df, skews, strikes = sc.make_fit_info(res['basedate'], raw_ivs_df2, forward_df['FORWARD'].values)
        res['forward_df'] = fit_info_df[['MATURITY', 'EXPIRY', 'YEARFRAC', 'FORWARD']]

        res['fit_info_df'] = fit_info_df
        res['skews'] = skews
        res['strikes'] = conf.target_strikes(undcode, res['spot'], False)
    return VolTu(**res)


def load_compare_info(basedt, source, undcode, tag) -> dict:
    res = dict()
    forward_df, spot = get_forwards(basedt, source, undcode, tag)
    res['basedt'] = basedt
    res['undcode'] = undcode
    res['forward_df'] = forward_df
    res['spot'] = spot
    res['data'] = True if forward_df is not None else False
    if not res['data']:
        return res

    res['raw_ivs_df'] = get_vols(basedt, source, undcode, tag)
    if res['raw_ivs_df'] is not None:
        res['params_df'] = None
        res['ivs_df'] = res['raw_ivs_df']
        res['strikes'] = res['raw_ivs_df'].columns.values
        res['mats'] = res['ivs_df'].index.values
    else:
        res['params_df'] = params_df = get_params(basedt, source, undcode, tag)
        strikes = conf.target_strikes(undcode, spot, is_fixed_strike=False)
        res['ivs_df'] = ivs_by_parameters(forward_df, strikes, params_df, index_to_str=True)
        res['strikes'] = strikes
        res['mats'] = res['ivs_df'].index.values
    return res


def load_iv(basedt, source, undcode, tag, strike_rule=conf.StrikeRule.NoRule) -> dict:
    res = dict()
    forward_df, spot = get_forwards(basedt, source, undcode, tag)
    res['basedt'] = basedt
    res['undcode'] = undcode
    res['forward_df'] = forward_df
    res['spot'] = spot
    res['data'] = True if forward_df is not None else False
    if not res['data']:
        return res
    res['raw_ivs_df'] = get_vols(basedt, source, undcode, tag)
    if res['raw_ivs_df'] is not None:
        res['params_df'] = None
        res['ivs_df'] = res['raw_ivs_df']
    else:
        res['params_df'] = params_df = get_params(basedt, source, undcode, tag)
        is_fixed_strike = True if strike_rule == conf.StrikeRule.Fixed_Strike else False
        strikes = conf.target_strikes(undcode, spot, is_fixed_strike=is_fixed_strike)
        res['ivs_df'] = ivs_by_parameters(forward_df, strikes, params_df, index_to_str=True)
    return res


def adjust_base_dic(base_dic, strike_rule, strikes, maturity_rule, mats):
    res_dic = base_dic.copy()
    if strike_rule == conf.StrikeRule.NoRule and maturity_rule == conf.MaturityRule.NoRule:
        return res_dic
    else:
        if strike_rule == conf.StrikeRule.NoRule:
            strikes = base_dic['ivs_df'].columns.values
        elif strike_rule == conf.StrikeRule.Fixed_Strike:
            strikes = conf.target_strikes(res_dic['undcode'], res_dic['spot'], is_fixed_strike=True)
        res_dic['strikes'] = strikes
        if maturity_rule == conf.MaturityRule.NoRule:
            mats = base_dic['ivs_df'].index.values
        if maturity_rule == conf.MaturityRule.Fixed_Maturity:
            mats = conf.fixed_constant_maturities()
        res_dic['mats'] = mats
        mps = [date.MaturityPeriod(base_dic['basedt'], e) for e in mats]

        maturities = [e.maturity for e in mps]
        res_dic['forward_df'] = util.outer_join_keys(maturities, res_dic['forward_df'])
        res_dic['forward_df']['EXPIRY'] = [date.to_datetime(e) for e in res_dic['forward_df'].index.values]

        if res_dic['raw_ivs_df'] is not None:
            # x: column, y: row
            raw_ivs_df = res_dic['raw_ivs_df']
            yearfracs = np.array([date.yearfrac(base_dic['basedt'], e) for e in raw_ivs_df.index.values])
            f = si.interp2d(raw_ivs_df.columns.values, yearfracs, raw_ivs_df.values)
        else:
            params_ivs_df = base_dic['ivs_df']
            yearfracs = np.array([date.yearfrac(base_dic['basedt'], e) for e in params_ivs_df.index.values])
            f = si.interp2d(params_ivs_df.columns.values, yearfracs, params_ivs_df.values)

        target_yearfracs = np.array([e.yearfrac for e in mps])
        data = [f(strike, target_yearfracs).flatten() for strike in strikes]
        ivs_df = pd.DataFrame(index=mats, columns=strikes)
        for i, strike in enumerate(strikes):
            # strike can be duplicated
            ivs_df.iloc[:, i].values[:] = data[i]
        res_dic['ivs_df'] = ivs_df
        return res_dic


def adjust_target_dic(target_dic, base_dt, strikes, maturity_rule, mats):
    res_dic = target_dic.copy()
    yearfracs = np.array([date.yearfrac(target_dic['basedt'], e) for e in res_dic['ivs_df'].index.values])
    f = si.interp2d(res_dic['ivs_df'].columns.values, yearfracs, res_dic['ivs_df'].values)
    if maturity_rule == conf.MaturityRule.Fixed_Maturity:
        mats = conf.fixed_constant_maturities()
    res_dic['mats'] = mats
    mps = [date.MaturityPeriod(target_dic['basedt'], e) for e in mats]
    maturities = [e.maturity for e in mps]
    res_dic['forward_df'] = util.outer_join_keys(maturities, res_dic['forward_df'])
    res_dic['forward_df']['EXPIRY'] = [date.to_datetime(e) for e in res_dic['forward_df'].index.values]

    target_yearfracs = np.array([e.yearfrac for e in mps])
    data = [f(strike, target_yearfracs).flatten() for strike in strikes]
    ivs_df = pd.DataFrame(index=mats, columns=strikes)
    for i, strike in enumerate(strikes):
        ivs_df.iloc[:, i].values[:] = data[i]
    res_dic['ivs_df'] = ivs_df
    return res_dic


def save_bloomberg_vol(basedt, undcode, tag, excel_ivs_df):
    source = 'BLOOMBERG'
    logger = util.get_logger()
    db = OTCORA(logger=logger)
    sql_rows = []

    another_tag = False
    db_ivs_df = get_vols(basedt, source, undcode, tag)
    if db_ivs_df is None:
        # this means that user try to save bloomberg vol with another tag
        another_tag = True
        db_ivs_df = pd.DataFrame(data=0, index=excel_ivs_df.index, columns=excel_ivs_df.columns)
    else:
        db_ivs_df = db_ivs_df.mask(pd.isnull(db_ivs_df), 0)
    excel_ivs_df = excel_ivs_df.mask(pd.isnull(excel_ivs_df), 0)
    diff_df = np.abs(excel_ivs_df - db_ivs_df)
    mask_df = diff_df.where(diff_df > 0, False)
    mask_df = mask_df.mask(diff_df > 0, True)
    target_df = excel_ivs_df[mask_df]
    df = target_df.unstack().reset_index(name='VALUE')
    df.columns = ['STRIKE', 'MATURITY', 'VALUE']
    df = df.dropna()

    msg = ''
    try:
        if another_tag:
            sql = (f"DELETE FROM YSK_VS_VOL WHERE BASEDATE='{basedt}' AND SOURCE='{source}'"
                   f" AND UNDCODE='{undcode}' AND TAG='{tag}'")
            db.execute(sql)

            sql_fmt = ("INTO YSK_VS_VOL(BASEDATE, SOURCE, UNDCODE, MATURITY, STRIKE, TAG, "
                       "BID, MID, ASK, TS) "
                       "VALUES ('{basedt}', '{source}', '{undcode}', '{maturity}', '{strike}', '{tag}', "
                       "'{bid}', '{mid}', '{ask}', SYSDATE)")

            sql_rows += [sql_fmt.format(basedt=basedt, source=source, undcode=undcode,
                                        maturity=e.MATURITY, strike=e.STRIKE, tag=tag,
                                        bid='', mid=e.VALUE, ask='')
                         for e in df.itertuples()]
            db.executemany(sql_rows)
            msg = f"insert {len(df)} bloomberg vols into db with tag '{tag}'"
            logger.info(msg)
        else:
            sql_fmt = ("UPDATE YSK_VS_VOL SET BID='', ASK='', MID='{value}' "
                       f"WHERE BASEDATE='{basedt}' AND SOURCE='{source}' AND UNDCODE='{undcode}' AND TAG='{tag}' "
                       "AND MATURITY='{maturity}' AND STRIKE={strike}")
            for e in df.itertuples():
                value = e.VALUE if e.VALUE else ''
                sql = sql_fmt.format(maturity=e.MATURITY, strike=e.STRIKE, value=value)
                db.execute(sql)
            msg = f"update {len(df)} bloomberg vols with tag '{tag}'"
            logger.info(msg)
    except Exception as e:
        db.rollback()
        logger.error(e)
        raise
    db.commit()
    return msg


def recent_vol_data():
    sql = (f"SELECT BASEDATE, SOURCE, TAG FROM (SELECT BASEDATE, SOURCE, TAG FROM YSK_VS_PARAM "
           f"GROUP BY BASEDATE, SOURCE, TAG ORDER BY BASEDATE DESC, SOURCE ASC)WHERE ROWNUM <= 20")
    return OTCORA().query_df(sql)


def make_fit_info_with_ysk_expiries(basedt, undcode, source, tag, ivs_df, forward_df, ffm):
    logger = util.get_logger()
    ivs_df.index = ivs_df['EXPIRY'].dt.strftime('%Y%m%d')
    forward_df.index = forward_df['MATURITY']

    ue = UnderlyingExpiry(undcode, basedt)
    und_maturities = ue.expiry_dts
    forward_ysk_mat_df = util.outer_join_keys(und_maturities, forward_df)
    forward_ysk_mat_df['EXPIRY'] = pd.to_datetime(forward_ysk_mat_df.index)
    forward_ysk_mat_df['MATURITY'] = forward_ysk_mat_df.index
    # does not fill na forward
    if False and any(pd.isnull(forward_ysk_mat_df)):
        forward_ysk_mat_df['F'] = forward_ysk_mat_df['FORWARD']
        fill_na_forward(basedt, undcode, source, tag, ffm, forward_ysk_mat_df)
        forward_ysk_mat_df['FORWARD'] = forward_ysk_mat_df['F']
        forward_ysk_mat_df = forward_ysk_mat_df.drop(columns=['F'])

    ivs_mat_df = util.outer_join_keys(und_maturities, ivs_df)
    ivs_mat_df['EXPIRY'] = pd.to_datetime(ivs_mat_df.index)

    mat_msg = ue.check_expiry_dts(forward_df['EXPIRY'].dt.strftime('%Y-%m-%d').values)
    return sc.make_fit_info(date.to_datetime(basedt), ivs_mat_df, forward_ysk_mat_df['FORWARD']) + (mat_msg,)


def svi_calibrate(fit_info_df, skews, calibrate_type='JW', inits=None, method='SLSQP',
                  interpolate_fitting_parameter=conf.InterpolateFittingParameter(0),
                  strikes=None):
    logger = util.get_logger()
    res = []
    ssvi = None
    fit_info_df['MASK'] = ''
    if calibrate_type == 'JW':
        if not inits:
            inits = [None for _ in range(len(fit_info_df['FORWARD'].values))]
        for f, t, skew, maturity, init in zip(fit_info_df['FORWARD'].values, fit_info_df['YEARFRAC'].values, skews,
                                              fit_info_df['MATURITY'].values, inits):
            if len(skew) > 0:
                jw = sc.SVI_JW(f, t, ks=skew.index.values, ivs=skew.values, method=method)
                res.append(jw.calibrate(x0=init, disp=True))
            else:
                logger.warning(f'there is no skew data[maturity={maturity}, f={f}]')
                res.append([np.nan] * len(conf.SVI_PARAMETERS))
        params_df = pd.DataFrame(data=res, index=fit_info_df['MATURITY'].values, columns=conf.SVI_PARAMETERS)
    elif calibrate_type == 'SSVI':
        ssvi = sc.Surface_SVI(fit_info_df[['W_ATM', 'YEARFRAC']], skews, method=method)
        res = ssvi.calibrate()
        params_df = pd.DataFrame(data=res, index=fit_info_df['MATURITY'].values, columns=conf.SVI_PARAMETERS)

    need_to_interpolate = False
    for i in range(len(res)):
        # interpolate svi params if forward is given and no skew data
        if np.isnan(res[i][0]) and np.isnan(fit_info_df.iloc[i]['FORWARD']) == False and len(skews[i]) == 0:
            need_to_interpolate = True
            break

    if interpolate_fitting_parameter == conf.InterpolateFittingParameter.DoesNotInterpolating:
        need_to_interpolate = False

    if not need_to_interpolate:
        logger.debug(f'\n{params_df}')
        logger.info(f"calibrate type: {calibrate_type}, no interpolating")
    else:
        params_df = _ssvi_interpolating(res, ssvi, fit_info_df, skews, calibrate_type, method,
                                        interpolate_fitting_parameter, strikes)
    return params_df


def _ssvi_interpolating(params, ssvi, fit_info_df, skews, calibrate_type, method,
                        interpolate_fitting_parameter, strikes):
    logger = util.get_logger()
    if interpolate_fitting_parameter == conf.InterpolateFittingParameter.SSVI_Interp:
        logger.info("start to interpolate svi parameters by SSVI Interp")
        if not ssvi:
            ssvi = sc.Surface_SVI(fit_info_df[['W_ATM', 'YEARFRAC']], skews, method=method)
            ssvi.calibrate()
        temp_df = fit_info_df[['W_ATM', 'YEARFRAC']].dropna()
        w_interp = si.interp1d(temp_df['YEARFRAC'].values, temp_df['W_ATM'].values,
                               bounds_error=False, fill_value='extrapolate')

        for i in range(len(params)):
            if np.isnan(params[i][0]) and np.isnan(fit_info_df.iloc[i]['FORWARD']) == False and len(skews[i]) == 0:
                yearfrac = fit_info_df.iloc[i]['YEARFRAC']
                params[i] = ssvi.get_jw_params(yearfrac, w_interp(yearfrac))
                fit_info_df['MASK'].iloc[i] = 'ssvi interpolated'
    else:
        logger.info("start to interpolate svi parameters by Total Variance Interp")
        df = fit_info_df[['FORWARD', 'MATURITY', 'YEARFRAC']].copy(deep=True)
        df['SKEW_STATUS'] = True
        for i in range(len(params)):
            if np.isnan(params[i][0]) and np.isnan(fit_info_df.iloc[i]['FORWARD']) == False and len(skews[i]) == 0:
                df['SKEW_STATUS'].iloc[i] = False
        # set prev mat and next mat
        df['PREV'] = df['MATURITY'].values
        df['NEXT'] = df['MATURITY'].values
        for i, e in enumerate(df.itertuples()):
            temp_df = df[(df['MATURITY'] < e.MATURITY) & df['SKEW_STATUS']]
            if i == 0:
                df['PREV'].iloc[i] = e.MATURITY if e.SKEW_STATUS else None
            else:
                df['PREV'].iloc[i] = max(temp_df['MATURITY'].values) if len(temp_df) > 0 else None
            temp_df = df[(df['MATURITY'] > e.MATURITY) & df['SKEW_STATUS']]
            if i == len(df) - 1:
                df['NEXT'].iloc[i] = e.MATURITY if e.SKEW_STATUS else None
            else:
                df['NEXT'].iloc[i] = min(temp_df['MATURITY'].values) if len(temp_df) > 0 else None
        # fill None
        df['PREV'] = df['PREV'].fillna(method='bfill')
        df['NEXT'] = df['NEXT'].fillna(method='ffill')
        # if PREV == NEXT set prev of prev mat to PREV
        end_df = df[df['PREV'] == df['NEXT']]
        prev_mats = sorted(set(df['PREV'].values))
        for e in end_df.itertuples():
            prev_prev_mat = prev_mats[max(prev_mats.index(e.PREV)-1, 0)]
            df.loc[e.Index, 'PREV'] = prev_prev_mat

        maturities = df['MATURITY'].values.tolist()
        for f, t, maturity, skew_status, prev_mat, next_mat, i \
                in zip(df['FORWARD'].values, df['YEARFRAC'].values,
                       df['MATURITY'].values, df['SKEW_STATUS'].values,
                       df['PREV'].values, df['NEXT'].values,
                       range(len(df))):
            if not skew_status:
                prev_idx = maturities.index(prev_mat)
                prev_t = df['YEARFRAC'].values[prev_idx]
                jw = sc.SVI_JW(df['FORWARD'].values[prev_idx], prev_t)
                prev_ivs = jw.get_iv(params[prev_idx], strikes)
                prev_tvar = prev_ivs**2 * t

                next_idx = maturities.index(next_mat)
                next_t = df['YEARFRAC'].values[next_idx]
                jw = sc.SVI_JW(df['FORWARD'].values[prev_idx], next_t)
                next_ivs = jw.get_iv(params[next_idx], strikes)
                next_tvar = next_ivs**2 * t

                # x: column, y: row
                interp_tvar = si.interp2d(strikes, [prev_t, next_t], [prev_tvar, next_tvar])
                ivs_tvar = interp_tvar(strikes, t)
                ivs = np.sqrt(ivs_tvar / t)
                ks = np.log(strikes / f)
                jw = sc.SVI_JW(f, t, ks=ks, ivs=ivs, method=method)
                params[i] = jw.calibrate(x0=None, disp=True)
                fit_info_df['MASK'].iloc[i] = 'total variance interpolated'

    params_df = pd.DataFrame(data=params, index=fit_info_df['MATURITY'].values, columns=conf.SVI_PARAMETERS)
    log_df = params_df.copy(deep=True)
    log_df['MASK'] = fit_info_df['MASK'].values
    log_df.index = fit_info_df['MATURITY'].values
    logger.debug(f'after interpolating params\n{log_df}')
    logger.info(f"calibrate type: {calibrate_type}, interpolated: {len(log_df[log_df['MASK'] != ''])} slices")
    return params_df


def ivs_by_parameters(forward_df, strikes, params_df, column_to_str=False, index_to_str=False):
    res = []
    for info, params in zip(forward_df.itertuples(), params_df.itertuples()):
        jw = sc.SVI_JW(info.FORWARD, info.YEARFRAC)
        res.append(jw.get_iv(list(params)[1:], strikes))
    columns = util.ndarray_to_list(strikes, True if column_to_str else False)
    indexes = forward_df.MATURITY if index_to_str else forward_df.EXPIRY
    res_df = pd.DataFrame(data=res, index=indexes, columns=columns)
    return res_df


def g_var_by_parameters(forward_df, params_df):
    res = []
    for info, params in zip(forward_df.itertuples(), params_df.itertuples()):
        jw = sc.SVI_JW(info.FORWARD, info.YEARFRAC)
        res.append(jw.get_g_var(list(params)[1:]))
    return res
