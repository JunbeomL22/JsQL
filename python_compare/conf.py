import numpy as np
import enum

DIVA_HOST = '160.61.161.43'
DIVA_PORT = '30080'


YEAR_DAY = 365.0
YEAR_SECONDS = 24 * 60 * 60 * YEAR_DAY
EPSILON = 1e-10
PRECISION = 10
EXPIRY_MAX_DAY = 4 * 365

SVI_PARAMETERS = ['JW_ATMVOL', 'JW_ATMSKEW', 'JW_PWING', 'JW_CWING', 'JW_MINVOL']


class UNDCODE(object):
    _UND_SHEET = {'KOSPI2': ['KOSPI200', 'KOSPI2', 'IVSKS'],
                  'SX5E': ['Eurostoxx50', 'IVSSX'],
                  'NKY': ['Nikkei225', 'IVSNK'],
                  'SPX': ['S&P500', 'IVSSP'],
                  'HSCEI': ['HSCEI', 'IVSHS'],
                  'HSI': ['HSI', 'IVSHSI'],
                  'NDX': ['NASDAQ100', 'IVSND'],
                  'TWSE': ['TAIEX', 'IVSTW'],
                  }
    _UNDS = [key for key in _UND_SHEET.keys()]

    _UND_IR = {'KOSPI2': 'KRWIRS', 'SX5E': 'EURIRS', 'NKY': 'JPYIRS',
               'SPX': 'USDIRS', 'HSCEI': 'HKDIRS', 'HSI': 'HKDIRS',
               'TWSE': 'TWDIRS', 'NDX': 'USDIRS'}

    @staticmethod
    def get_codes():
        return UNDCODE._UNDS

    @staticmethod
    def get_ircode(code):
        return UNDCODE._UND_IR[code]

    @staticmethod
    def get_code_by_sheetname(name):
        res = None
        for k, names in UNDCODE._UND_SHEET.items():
            if name in names:
                res = k
                break
        return res

    @staticmethod
    def check_code(code):
        return code in UNDCODE._UNDS

    @staticmethod
    def get_sheetname(code, vendor='NICE'):
        vendor_idx = 0 if vendor == 'NICE' else -1
        res = None
        for k, v in UNDCODE._UND_SHEET.items():
            if k == code:
                res = v[vendor_idx]
                break
        return res


class IRCODE(object):
    _YSK_IR_CODE_RCODE = {'KRWIRS': 'SI02001', 'USDIRS': 'IRSUSDUSD', 'HKDIRS': 'IRSHKDHKD',
                          'JPYIRS': 'IRSJPYJPY', 'EURIRS': 'IRSEUREUR', 'TWDIRS': 'IRSTWDTWD'}

    _YSK_IR_RCODE_CODE = {v: k for k, v in _YSK_IR_CODE_RCODE.items()}

    @staticmethod
    def get_ir_riskcode(ircode):
        return IRCODE._YSK_IR_CODE_RCODE[ircode]

    @staticmethod
    def get_ircode(riskcode):
        return IRCODE._YSK_IR_RCODE_CODE[riskcode]

    @staticmethod
    def check_ircode(ircode):
        return ircode in IRCODE.get_ircodes()

    @staticmethod
    def get_ircodes():
        return [key for key in IRCODE._YSK_IR_CODE_RCODE.keys()]

    @staticmethod
    def get_ir_riskcodes():
        return [key for key in IRCODE._YSK_IR_RCODE_CODE.keys()]


UND_HOLIDAY_MARKET = {'KOSPI2': 'KR', 'NKY': 'JP', 'HSCEI': 'HK', 'HSI': 'HK',
                      'SX5E': 'UK', 'SPX': 'US', 'VIX': 'US', 'CLA': 'US', 'COA': 'US'}


def is_margined_underlying(und):
    if und in ['HSCEI', 'HSI', 'CLA', 'COA']:
        return True
    else:
        return False


BLP_OPT_INFO = {
    'KOSPI2': {
        'spot_ticker': 'KOSPI2 Index',
        'm_lower': 0.6,
        'm_upper': 1.4,
        'step': 2.5,
        'target_strike_step': 15,
        'fut_prefix': 'KM'
    },
    'NKY': {
        'spot_ticker': 'NKY Index',
        'm_lower': 0.6,
        'm_upper': 1.4,
        'step': 125,
        'target_strike_step': 750,
        'fut_prefix': 'NK'
    },
    'HSCEI': {
        'spot_ticker': 'HSCEI Index',
        'm_lower': 0.5,
        'm_upper': 1.5,
        'step': 100,
        'target_strike_step': 600,
        'fut_prefix': 'HC'
    },
    'HSI': {
        'spot_ticker': 'HSI Index',
        'm_lower': 0.5,
        'm_upper': 1.5,
        'step': 200,
        'target_strike_step': 1100,
        'fut_prefix': 'HI'
    },
    'SX5E': {
        'spot_ticker': 'SX5E Index',
        'm_lower': 0.5,
        'm_upper': 1.5,
        'step': 25,
        'target_strike_step': 150,
        'fut_prefix': 'VG'
    },
    'SPX': {
        'spot_ticker': 'SPX Index',
        'm_lower': 0.5,
        'm_upper': 1.5,
        'step': 10,
        'target_strike_step': 100,
        'fut_prefix': 'SP'
    },
    'TWSE': {
        'spot_ticker': 'TWSE Index',
    },
    'NDX': {
        'spot_ticker': 'NDX Index',
    },
}


def target_strikes(und, spot, is_fixed_strike=False):
    res = None
    if is_fixed_strike:
        dk = BLP_OPT_INFO[und]['target_strike_step']
        atm = int(spot / dk) * dk
        target_ks = np.array([atm + (dk * i) for i in range(-10, 11) if 0.5 * spot <= atm + (dk * i) <= 1.5 * spot])
        res = target_ks[:21]
    else:
        res = np.linspace(0.5, 1.5, 21) * spot
    res = np.array([np.float64(f'{e:.10g}') for e in res])
    return res


def fixed_constant_maturities():
    return ['1M', '2M', '3M', '6M', '12M', '18M', '2Y', '3Y', '5Y']


class AHInterpTarget(enum.IntEnum):
    TargetCall = 0
    TargetPut = 1
    TargetStraddle = 2  # use call and put  with forward reference as a target price


class FFillMethod(enum.IntEnum):
    # fill forward na values
    FF_None = 0  # Do nothing
    FF_Prev_Basis = 1  # Using recent basis
    FF_Prev_NICE_Basis = 2  # Using recent nice basis
    FF_Prev_Basis_All = 3  # Using recent data, fill all forward values except 1st forward value
    FF_Linear_Interp = 4  # naive interpolation


class RibbonCompare(enum.IntEnum):
    # Compare with prev or original data
    NoAction = 0
    Compare_with_prev_data = 1
    Compare_with_raw_data = 2


class StrikeRule(enum.IntEnum):
    # volsurface shape strike rule
    NoRule = 0
    Fixed_Strike = 1
    Excel_Strike = 2


class MaturityRule(enum.IntEnum):
    # volsurface shape maturity rule
    NoRule = 0
    Fixed_Maturity = 1
    Excel_Maturity = 2


class InterpolateFittingParameter(enum.IntEnum):
    DoesNotInterpolating = 0
    SSVI_Interp = 1
    Total_Variance_Interp = 2


LOGGING_CONFIG = {
    'version': 1,
    'disable_existing_loggers': True,
    'formatters': {
        'default': {
            'format': '%(asctime)s - %(name)-12s - %(levelname)-7s - %(filename)s,%(lineno)d - %(message)s',
            'datefmt': '%m/%d %H:%M:%S'
        },
        'fmt1': {
            'format': '%(asctime)s - %(levelname)-7s - %(filename)s,%(lineno)d - %(message)s',
            'datefmt': '%m/%d %H:%M:%S'
        },
    },
    'handlers': {
        'console': {
            'level': 'DEBUG',
            'formatter': 'default',
            'class': 'logging.StreamHandler',
            'stream': 'ext://sys.stdout',
        },
        'root.log': {
            'level': 'DEBUG',
            'formatter': 'default',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': r'.\log\root.log',
            'maxBytes': 10 * 1024 * 1024,
            'backupCount': 3,
        },
        'volsurface.log': {
            'level': 'DEBUG',
            'formatter': 'default',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': r'.\log\volsurface.log',
            'maxBytes': 10 * 1024 * 1024,
            'backupCount': 3,
        },
        'upload_vendor_vol.log': {
            'level': 'DEBUG',
            'formatter': 'default',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': r'.\log\upload_vendor_vol.log',
            'maxBytes': 10 * 1024 * 1024,
            'backupCount': 3,
        },
        'upload_bloomberg.log': {
            'level': 'DEBUG',
            'formatter': 'default',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': r'.\log\upload_bloomberg.log',
            'maxBytes': 10 * 1024 * 1024,
            'backupCount': 3,
        },
    },
    'loggers': {
        'root': {
            'handlers': ['console', 'root.log'],
            'level': 'DEBUG',
            'propagate': False
        },
        'volsurface': {
            'handlers': ['console', 'volsurface.log'],
            'level': 'DEBUG',
            'propagate': False
        },
        'upload_vendor': {
            'handlers': ['console', 'upload_vendor_vol.log'],
            'level': 'DEBUG',
            'propagate': False
        },
        'upload_bloomberg': {
            'handlers': ['console', 'upload_bloomberg.log'],
            'level': 'DEBUG',
            'propagate': False
        }
    }
}
