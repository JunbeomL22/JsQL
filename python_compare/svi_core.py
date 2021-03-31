import numpy as np
import scipy.optimize as so
import scipy.interpolate as si
import pandas as pd
import copy
from common import conf

# ref: [1] Arbitrage-free SVI volatility surfaces(Jim Gatheral, Antoine Jacquier)


class AbstractFitting(object):
    def __init__(self):
        pass

    def _initialize(self):
        pass

    def _convert_params(self, x):
        raise NotImplementedError()

    def _target(self, x):
        raise NotImplementedError()

    def calibrate(self, x0):
        raise NotImplementedError()

    def get_iv(self):
        raise NotImplementedError()


class RAW_SVI(AbstractFitting):
    def __init__(self, f, t, strikes, ivs, method='SLSQP'):
        self.f = f
        self.t = t
        self.strikes = strikes
        self.ks = np.log(self.strikes / self.f)
        self.ivs = ivs
        self.method = method
        self.constraints = (
            #{'type': 'ineq', 'fun': lambda x: x[3] - 3}
        )
        self._initialize()
        pass

    def _initialize(self):
        pass

    def _convert_params(self, x):
        pass

    def _target(self, x):
        t = self.t
        ks = self.ks
        ivs = self.ivs
        a, b, r, m, s = x
        var = (a + b * (r * (ks - m) + np.sqrt((ks - m)**2 + s**2))) / t
        return ((var / ivs**2 - 1)**2).mean()

    def calibrate(self, x0=None, disp=False):
        if x0 is None:
            x0 = np.array([0.1, 0.1, 0.1, 0.1, 0.1])
        res = so.minimize(self._target, x0, constraints=self.constraints, method=self.method,
                          options={'disp': disp, 'maxiter': 1000, 'ftol': 1e-8})
        return res['x']

    @staticmethod
    def get_raw_svi_iv(f, t, k, args):
        a, b, r, m, s = args
        k = np.log(k / f)
        var = (a + b * (r * (k - m) + np.sqrt((k - m) ** 2 + s ** 2))) / t
        return np.sqrt(var)

    @staticmethod
    def get_jw_params(f, t, args):
        a, b, rho, m, sigma = args
        v = (a + b * (-rho * m + np.sqrt(m**2 + sigma**2))) / t
        rw = np.sqrt(v * t)
        psi = b / rw / 2 * (-m / np.sqrt(m**2 + sigma**2) + rho)
        p = b / rw * (1 - rho)
        c = b / rw * (1 + rho)
        vt = 1 / t * (a + b * sigma * np.sqrt(1 - rho**2))
        return [v, psi, p, c, vt]


class SVI_JW(AbstractFitting):
    def __init__(self, f, t,
                 strikes=None, ks=None, ivs=None,  # for calibrate
                 method='SLSQP'):
        self.f = f
        self.t = t
        self.strikes = strikes
        self.ivs = ivs
        self.method = method
        self.ks = ks
        self.constraints = (
            {'type': 'ineq', 'fun': lambda x: x[0] - conf.EPSILON},
            {'type': 'ineq', 'fun': lambda x: 2 * x[1] + x[2]},
            {'type': 'ineq', 'fun': lambda x: -2 * x[1] + x[3]},  # -1 <= beta < = 1

            {'type': 'ineq', 'fun': lambda x: x[2]},
            {'type': 'ineq', 'fun': lambda x: x[3]},  # -1 <= rho < = 1, b > 0

            {'type': 'ineq', 'fun': lambda x: x[0] - x[4]},  # v > vt
        )
        # TODO: use bounds. ex) bnds = ((0, None), (0, None))
        self._prev_cost = 1000

    def _initialize(self):
        if not self.ks:
            self.ks = np.log(self.strikes / self.f)

    def _convert_params(self, x, t):
        v, psi, p, c, vt = x
        w = v * t
        rw = np.sqrt(w)

        b = rw / 2. * (c + p)
        rho = 1 - p * rw / b
        if np.abs(rho) > 1:
            rho = np.sign(rho)
        beta = rho - 2 * psi * rw / b
        if np.abs(beta) > 1:
            beta = np.sign(beta)
        if np.isnan(beta):
            print(f't={t}, beta={beta}')
        alpha = np.sqrt(1 / beta**2 - 1) * np.sign(beta)
        rr = np.sqrt(1 - rho**2)
        m = (v - vt) * t / (b * (-rho + np.sign(alpha) * np.sqrt(1 + alpha**2) - alpha * rr))
        sigma = alpha * m
        if m == 0:
            sigma = (w - vt * t) / b / (1 - rr)
        a = vt * t - b * sigma * rr
        return [a, b, rho, m, sigma]

    def _target(self, x):
        t = self.t
        ks = self.ks
        ivs = self.ivs

        x = self._convert_params(x, t)
        a, b, r, m, s = x
        var = (a + b * (r * (ks - m) + np.sqrt((ks - m) ** 2 + s ** 2))) / t
        cost = ((var / ivs**2 - 1) ** 2).mean()
        if np.isnan(cost):
            cost = self._prev_cost * 10
        else:
            self._prev_cost = cost
        return cost

    def calibrate(self, x0=None, disp=False):
        if x0 is None:
            x0 = np.array([0.02, -0.1, 2, 1, 0.01])
        res = so.minimize(self._target, x0, constraints=self.constraints, method=self.method,
                          options={'disp': disp, 'maxiter': 1000, 'ftol': 1e-8})
        return res['x']

    def get_iv(self, args, k):
        f = self.f
        t = self.t
        raws = self.get_raw_params(args)
        a, b, r, m, s = raws
        k = np.log(k / f)
        var = (a + b * (r * (k - m) + np.sqrt((k - m)**2 + s**2))) / t
        return np.sqrt(var)

    def get_raw_params(self, x):
        return self._convert_params(x, self.t)

    def get_g_var(self, args):
        # (2.1) of [1]
        k = np.linspace(-1.5, 1.5, 301)
        dk = 0.01
        raws = self.get_raw_params(args)
        a, b, r, m, s = raws
        var = (a + b * (r * (k - m) + np.sqrt((k - m)**2 + s**2)))
        w = pd.Series(data=var, index=k)
        # dw / dk = (w(s+) - w(s-)) / 2dk
        d_w = (w.shift(-1) - w.shift(1)) / (2 * dk)
        # d^2w / dk^2 = (w(s+) - 2w(s) + w(s-)) / dk^2
        d2_w = (w.shift(-1) - 2 * w + w.shift(1)) / dk ** 2
        g = (1 - k * d_w / (2 * w)) ** 2 - d_w ** 2 / 4 * (1 / w + 0.25) + d2_w / 2
        # w.to_csv('w.csv')
        return g, w

    @staticmethod
    def convert_params_trader_to_original(params):
        # trader's jw show vol. original jw represent variance.
        x = params.copy()
        if isinstance(x, pd.DataFrame):
            x[x.columns[0]] = x[x.columns[0]] ** 2.0
            x[x.columns[-1]] = x[x.columns[-1]] ** 2.0
            return x
        else:
            x[0] = x[0]**2.0
            x[-1] = x[-1]**2.0
            return x

    @staticmethod
    def convert_params_original_to_trader(params):
        # trader's jw show vol. original jw represent variance.
        x = params.copy()
        if isinstance(x, pd.DataFrame):
            x[x.columns[0]] = np.sqrt(x[x.columns[0]])
            x[x.columns[-1]] = np.sqrt(x[x.columns[-1]])
        else:
            x[0] = np.sqrt(x[0])
            x[-1] = np.sqrt(x[-1])
        return x


class Surface_SVI(AbstractFitting):

    def __init__(self, fit_info_df, skews, method='SLSQP'):
        self.method = method
        self.fit_info_df = fit_info_df[['W_ATM', 'YEARFRAC']]
        self.skews = skews
        self.result = None
        self.constraints = (
            {'type': 'ineq', 'fun': lambda x: 1 - np.abs(x[0])},  # |rho| < 1

            {'type': 'ineq', 'fun': lambda x: x[1]},  # eta > 0

            {'type': 'ineq', 'fun': lambda x: x[2]},
            {'type': 'ineq', 'fun': lambda x: 1 - x[2]},  # 0 < gamma < 1

            # theta * phi * (1 + |rho|) < 4
            {'type': 'ineq', 'fun': lambda x: 4 - (x[3] * (x[1] * x[3]**-x[2]) * (1 + np.abs(x[0])))},
            # theta * phi^2 * (1 + |rho|) < 4
            {'type': 'ineq', 'fun': lambda x: 4 - (x[3] * (x[1] * x[3]**-x[2])**2 * (1 + np.abs(x[0])))},
        )

    def _convert_params(self, x, k):
        rho, eta, gamma, theta = x
        phi = eta * theta**-gamma
        cx = [rho, theta, phi, k]
        return cx

    def _total_var(self, cx):
        rho, theta, phi, k = cx
        return theta / 2 * (1 + rho * phi * k + np.sqrt((phi * k + rho)**2 + 1 - rho**2))

    def _target(self, x):
        cost = 0
        for skew, theta, t in zip(self.skews, self.fit_info_df['W_ATM'].values, self.fit_info_df['YEARFRAC'].values):
            for k, iv in zip(skew.index, skew.values):
                x[3] = theta
                cx = self._convert_params(x, k)
                cost += (self._total_var(cx) - iv**2 * t)**2
        return cost

    def calibrate(self, x0=None):
        if x0 is None:
            x0 = [0.01, 0.01, 0.5, 0.01]
        res = so.minimize(self._target, x0, constraints=self.constraints, method=self.method)
        self.result = res['x']
        return self.get_jw_init_params()

    def get_jw_init_params(self):
        rho, eta, gamma, theta = self.result
        inits = []
        for t, theta in zip(self.fit_info_df['YEARFRAC'].values, self.fit_info_df['W_ATM'].values):
            v = theta / t
            psi = rho / 2 * np.sqrt(theta) * eta * theta**-gamma
            p = psi / rho * (1 - rho)
            c = psi / rho * (1 + rho)
            vt = theta / t * (1 - rho**2)
            inits.append([v, psi, p, c, vt])
        return inits

    def get_jw_params(self, t, theta):
        rho, eta, gamma, _ = self.result
        v = theta / t
        psi = rho / 2 * np.sqrt(theta) * eta * theta**-gamma
        p = psi / rho * (1 - rho)
        c = psi / rho * (1 + rho)
        vt = theta / t * (1 - rho**2)
        return [v, psi, p, c, vt]

    def get_ssvi_params(self):
        return self.result

    def get_iv(self):
        pass

    def get_byproducts(self):
        return self.fit_info_df.copy(deep=True), copy.deepcopy(self.skews)


def make_fit_info(basedate, ivs, forwards):
    df = ivs.copy(deep=True)
    if not isinstance(ivs, pd.DataFrame):
        df = pd.DataFrame(ivs[1:], columns=['EXPIRY'] + ivs[0][1:])
    strikes = np.array(df.columns.values[1:], dtype=float)
    dates = np.array(df['EXPIRY'])
    assert (len(dates) == len(forwards))
    df['YEARFRAC'] = df['EXPIRY'].apply(lambda x: (x - basedate).days / conf.YEAR_DAY)
    df['FORWARD'] = forwards
    df['MATURITY'] = df.index

    iv_atms = []
    w_atms = []
    skews = []
    for i, row in df.iterrows():
        skew = row[strikes].dropna()
        if len(skew):
            skew.index = np.log(skew.index.values / row['FORWARD'])
            skews.append(skew)

            interp = si.interp1d(skew.index.values, skew.values)
            iv_atm = interp(0)
            iv_atms.append(float(iv_atm))
            w_atms.append(iv_atm**2 * row['YEARFRAC'])
        else:
            skews.append(skew)
            iv_atms.append(np.nan)
            w_atms.append(np.nan)
    df['IV_ATM'] = iv_atms
    df['W_ATM'] = w_atms

    return df, skews, strikes


def check_svi_jw():
    f = 309.5497085769098
    t = 0.5
    iv_atm = 0.12017662661493637
    strikes = np.array([220, 222.5, 225, 227.5, 230, 232.5, 235, 237.5, 240, 242.5, 245, 247.5, 250, 252.5, 255, 257.5, 260, 262.5, 265, 267.5, 270, 272.5, 275, 277.5, 280, 282.5, 285, 287.5, 290, 292.5, 295, 297.5, 300, 302.5, 305, 307.5, 310, 312.5, 315, 317.5, 320, 322.5, 325, 327.5, 330, 332.5, 335, 337.5, 340, 342.5, 345, 347.5, 350, 352.5], dtype=float)
    ivs = np.array([0.521851238, 0.505781477, 0.48986602, 0.474100254, 0.458479644, 0.442999721, 0.427656076, 0.412444342, 0.397360183, 0.382399283, 0.367557328, 0.352829989, 0.338212906, 0.323701666, 0.309291779, 0.294978649, 0.280757545, 0.266623557, 0.270428485, 0.267111204, 0.251821672, 0.244725278, 0.235575346, 0.229711758, 0.217308187, 0.21046759, 0.20323033, 0.195013452, 0.184065693, 0.174674119, 0.165205304, 0.15619468, 0.147383637, 0.139189047, 0.129073383, 0.120176627, 0.112920641, 0.109135174, 0.107708837, 0.107795457, 0.109544981, 0.108586837, 0.1113023, 0.114294662, 0.127552926, 0.124071945, 0.135621098, 0.146986126, 0.158179971, 0.169213458, 0.180095795, 0.190834933, 0.201437823, 0.211910609], dtype=float)
    x0 = np.array([-1.080149508, 4.005722067, 0.637772933, 0.320348027, -0.353873819])
    method = 'SLSQP'

    jw = SVI_JW(f, t, strikes=strikes, ivs=ivs, method=method)
    res = jw.calibrate(x0)
    print(res)


def check_calibrate_svi_jw_1():
    import datetime
    basedate = datetime.datetime(2018, 3, 12)
    ivs = [['expiry', 2200.0, 2250.0, 2300.0, 2350.0, 2400.0, 2450.0, 2500.0, 2550.0, 2600.0, 2650.0, 2700.0, 2750.0, 2800.0, 2850.0, 2900.0, 2950.0, 3000.0, 3050.0, 3100.0, 3150.0, 3200.0, 3250.0, 3300.0, 3350.0, 3400.0, 3450.0, 3500.0, 3550.0, 3600.0, 3650.0, 3700.0, 3750.0, 3800.0, 3850.0, 3900.0, 3950.0, 4000.0, 4050.0, 4100.0, 4150.0, 4200.0, 4250.0, 4300.0, 4350.0, 4400.0, 4500.0, 4600.0], [datetime.datetime(2018, 3, 16, 0, 0), None, None, None, None, None, None, None, None, None, None, None, None, None, None, None, None, None, 0.455369255906091, 0.405359528388057, 0.362996839261136, 0.320826229398883, 0.270414530198658, 0.223551073306683, 0.177252457955128, 0.149358108777873, 0.139865320930019, 0.153324335752008, 0.175743573464739, 0.208529608442635, 0.233834585018677, None, None, 0.364197730569743, None, None, None, None, None, None, None, None, None, None, None, None, None, None], [datetime.datetime(2018, 4, 20, 0, 0), None, None, 0.431840792365944, 0.42196700548417, 0.400116051940344, 0.383302985490533, 0.369856580600179, 0.35504916442186, 0.344320953687819, 0.327125305923634, 0.313078424454359, 0.299128543500571, 0.286091261757266, 0.272126311427186, 0.259600441088632, 0.245942300308352, 0.232111551256893, 0.219578185098548, 0.207422633507028, 0.194310157297053, 0.181335725380073, 0.168756441434342, 0.156982764973371, 0.145898782053906, 0.13542669553585, 0.12643122875512, 0.119177116125233, 0.114426668439316, 0.113733866221924, 0.115009082380443, 0.118071176508994, 0.124901091406419, 0.132573859450328, 0.138023603699646, 0.146880505367159, 0.159444475660949, None, None, None, None, None, None, None, None, None, None, None], [datetime.datetime(2018, 5, 18, 0, 0), 0.37600664331686, 0.364249328783646, 0.354202418735727, 0.342806960051267, 0.332243526334667, 0.320467003026118, 0.310360552087711, 0.298860253919887, 0.289040497583379, 0.279884873311636, 0.270730259732265, 0.259663245362499, 0.249742816040638, 0.239020967912316, 0.22955407326198, 0.220306300923564, 0.210394134921083, 0.200194554417201, 0.190676904273099, 0.180912351413883, 0.171572431900007, 0.161776230609693, 0.15239719682234, 0.143901402367245, 0.136248322990704, 0.129443909326007, 0.124334489896917, 0.120352517042181, 0.11879909743251, 0.118865110130204, 0.120063051689323, 0.12190883202582, 0.125332839446602, 0.129613575964033, 0.133375050689854, 0.135448333734546, 0.144998523781352, None, None, None, None, None, None, None, None, None, None], [datetime.datetime(2018, 6, 15, 0, 0), 0.342041397388794, 0.333958091390393, 0.324473289500292, 0.312978852591259, 0.304408937653408, 0.295999189032259, 0.287461729787904, 0.279134381464457, 0.269371908620923, 0.262292146606959, 0.253975347986175, 0.245965062412899, 0.238058477292554, 0.230273293290378, 0.222019778490108, 0.213683217159525, 0.205010968316705, 0.196369925790062, 0.187778039003043, 0.1793263657422, 0.170876315256139, 0.161984597427408, 0.15421153985265, 0.146402069147658, 0.139846034760829, 0.133808996406293, 0.128883084613725, 0.126366568029617, 0.123878554314306, 0.123373861199032, 0.123146447026314, 0.124483278872142, 0.125432552627932, 0.127171478620034, 0.12985749381348, 0.132915223168535, 0.13252083129543, 0.140616285225769, 0.145862764198583, None, None, None, None, None, None, None, None], [datetime.datetime(2018, 9, 21, 0, 0), 0.303352233530901, 0.296373466598971, 0.289757983611687, 0.283031319893962, 0.277968891417717, 0.279524647071541, 0.265659101081673, 0.259079901839976, 0.252414801602307, 0.245702098980255, 0.238952800425132, 0.231066394904126, 0.224301156330083, 0.217423509720804, 0.210895548077821, 0.204319134662018, 0.197815336559219, 0.191579622425236, 0.184741547344826, 0.178361825002137, 0.171917687644384, 0.165656407467746, 0.159670716918328, 0.154050047349709, 0.148600951187965, 0.144320436882013, 0.140088630408951, 0.13616064213425, 0.133316311707831, 0.130829406834556, 0.129391578465191, 0.12824522157983, 0.128028752885047, 0.127618429232579, 0.128092254924227, 0.129016377028672, 0.131176133330373, 0.130158460133377, 0.131135500372056, 0.132524629577321, 0.133736850466184, 0.135178840393255, 0.137551357038602, 0.139009093321337, 0.142676701863091, None, None], [datetime.datetime(2018, 12, 21, 0, 0), 0.257879350834227, 0.273873787564435, 0.242694374653133, 0.262730737889237, 0.257382159421251, 0.251609730094335, 0.245676828597782, 0.240078016289021, 0.236002123278642, 0.229104998706253, 0.223208088967044, 0.217938018747543, 0.212156736916586, 0.206656377773221, 0.201525123598169, 0.194415508958804, 0.190787370888183, 0.18547138448146, 0.180155649693308, 0.17494648090696, 0.170015473377445, 0.165119008606246, 0.160468415110917, 0.156143123479249, 0.152031317588866, 0.148287519218726, 0.144784626151403, 0.141561681575382, 0.138845529172788, 0.136446622537001, 0.134852663020632, 0.132888007502453, 0.131697653666983, 0.130955885086094, 0.130819381189996, 0.130734698567055, 0.130812671926109, 0.131010894501521, 0.131578185515987, 0.132124374545886, 0.132687002605678, 0.132909172256964, 0.133347579762915, 0.134517762164878, 0.134703517075734, 0.138645040736422, None], [datetime.datetime(2019, 6, 21, 0, 0), 0.250722399971145, 0.246211876697254, 0.249706357498095, 0.236620876326355, 0.231832588111974, 0.227220842906454, 0.222637806560518, 0.217907401522275, 0.213405790143078, 0.208880109586329, 0.204483022611692, 0.200329307727823, 0.195873904339265, 0.191919900478002, 0.187520266481819, 0.183891981193312, 0.180016343622209, 0.176338894726813, 0.172857369094699, 0.169399609118449, 0.166052246551901, 0.162764789817215, 0.159666100829559, 0.156653823670926, 0.153845412767204, 0.151793616622681, 0.149159552124291, 0.147037958614547, 0.14491665386934, 0.143279857131734, 0.141966111844683, 0.140833715936893, 0.162153688552696, 0.138741399335598, 0.138203503232929, 0.137845473482998, 0.139084275517014, 0.137543398879331, 0.137701367842243, 0.137752876894157, 0.138053244830584, 0.138546864842247, 0.13878284398521, 0.139336065833282, 0.139624164962031, None, 0.140540704234678], [datetime.datetime(2019, 12, 20, 0, 0), 0.235759035193239, 0.231327621355421, 0.227075118913595, None, 0.218864608336827, 0.214915553299737, 0.211135005667826, 0.207415291781107, 0.203844088929741, 0.200364416590361, 0.1970075973228, 0.193722394207713, 0.190573951873542, 0.187477669770943, 0.184462111490386, 0.181552319890983, 0.178771577573101, 0.176050609369735, 0.173419498998722, 0.170879125030226, 0.168404641074472, 0.165976078585984, 0.163694921109144, 0.161433053919334, 0.159362820439055, 0.157877446494602, 0.155958132911683, 0.15426939458289, 0.152750426229673, 0.151409866673398, 0.150122905924937, 0.148934405324045, 0.147863503590848, 0.146895408022535, 0.146013941844379, 0.14524752878855, 0.144581056218057, 0.143936539147561, 0.143509910496635, 0.143166341179393, 0.143713977206025, 0.142584554897969, 0.142521121972487, 0.142424228522813, 0.142458428208778, 0.142643462108969, 0.142975011852054], [datetime.datetime(2020, 12, 18, 0, 0), 0.213537588228139, None, 0.20710793607533, None, 0.201182016370843, 0.198423322996391, 0.195784957327623, None, 0.190863506759921, 0.188548897811905, 0.186383120108788, 0.184280666913184, 0.182249536926336, 0.180298061288977, 0.178461426052705, 0.176697506193016, 0.17499469625366, 0.173369026657181, 0.171764334098573, 0.170201549317696, 0.168727066187245, 0.167268217339507, 0.165875645261504, 0.164529777827921, 0.163286919075157, 0.162514014759199, 0.161415085980739, 0.160384224851126, 0.159412818555449, 0.158575404549718, 0.157787998091381, 0.157074351168513, 0.156402388211005, 0.155798474025772, 0.155228875261902, 0.154688086552366, 0.154204874774358, 0.153813087301972, 0.153436045100849, 0.153102883789369, 0.152804891645049, 0.152575464229889, 0.152358124530846, 0.152182695159958, 0.152084441202331, 0.151991028157531, 0.151978359027261]]
    fwds = [3429.4, 3415.2, 3370.25, 3341.95, 3332.0, 3314.9, 3218.6, 3196.25, 3096.1]
    fwd_dates = [datetime.datetime(2018, 3, 16, 0, 0), datetime.datetime(2018, 4, 20, 0, 0), datetime.datetime(2018, 5, 18, 0, 0), datetime.datetime(2018, 6, 15, 0, 0), datetime.datetime(2018, 9, 21, 0, 0), datetime.datetime(2018, 12, 21, 0, 0), datetime.datetime(2019, 6, 21, 0, 0), datetime.datetime(2019, 12, 20, 0, 0), datetime.datetime(2020, 12, 18, 0, 0)]
    # inits = [[0.020666816185213818, -0.4509601166185134, 1.3477126607162824, 0.4457924274792557, 0.015440392538493266], [0.017603492621873308, -0.33521772630065, 1.0018118170172672, 0.33137636441596713, 0.013151751759647336], [0.019821326133657762, -0.30561740812178917, 0.9133500615298565, 0.3021152452862782, 0.014808718159313542], [0.021800962252481477, -0.28716876808652275, 0.8582155500015147, 0.28387801382846917, 0.016287724818301794], [0.0243558987734229, -0.25601290111981534, 0.7651049736572562, 0.2530791714176255, 0.018196544369447367], [0.025335936032395607, -0.24118794838463226, 0.7207999990942208, 0.23842410232495626, 0.01892874036157672], [0.027166737097809205, -0.22283122679922548, 0.6659401895939832, 0.22027773599553221, 0.020296550809811235], [0.0284222110150577, -0.21142879523806696, 0.6318635588419026, 0.20900596836576868, 0.02123452838363926], [0.029545679170201563, -0.1975505659187558, 0.5903879057349074, 0.1952867738973958, 0.022073883084646806]]
    method = 'SLSQP'

    if not isinstance(basedate, datetime.datetime):
        Exception('basedate must be datetime')
    fwds = np.array(fwds, dtype=float)
    inits = None
    fit_info_df, skews, _ = make_fit_info(basedate, ivs, fwds)
    if not inits:
        ssvi = Surface_SVI(fit_info_df, skews, method=method)
        res_df = pd.DataFrame(data=ssvi.calibrate(), columns=conf.SVI_PARAMETERS)

        print(res_df)
        inits = res_df.values

    res = []
    for f, t, skew, init in zip(fit_info_df['FORWARD'].values, fit_info_df['YEARFRAC'].values, skews, inits):
        jw = SVI_JW(f, t, ks=skew.index.values, ivs=skew.values, method=method)
        x = jw.calibrate(x0=init, disp=True)
        res.append(x)
    res_df = pd.DataFrame(data=res, columns=conf.SVI_PARAMETERS)
    print(res_df)


def check_convert_trader_jw_to_original():
    s = "0.013569 -0.299625  6.653824  518.153591  0.01156"
    res = [s.split(), s.split()]
    res_df = pd.DataFrame(data=res, columns=['v', 'psi', 'p', 'c', 'vt'], dtype=float)
    trader_jw_df = SVI_JW.convert_params_original_to_trader(res_df)
    original_df = SVI_JW.convert_params_trader_to_original(trader_jw_df)
    print('DataFrame')
    print(res_df)
    print(trader_jw_df)
    print(original_df)

    res = res_df.iloc[0].values.tolist()
    traders = SVI_JW.convert_params_original_to_trader(res)
    originals = SVI_JW.convert_params_trader_to_original(traders)
    print('list')
    print(res)
    print(traders)
    print(originals)


def check_get_svi_jw_iv():
    f = 2791.0
    t = 1
    k = np.array([2791.0, 2810.55])
    args = np.array([0.286406099, -0.319344278, 0.662583095, 0.14212753, 0.204963772], dtype=float)
    args = SVI_JW.convert_params_trader_to_original(args)
    jw = SVI_JW(f, t)
    iv = jw.get_iv(args, k)
    print(iv)


if __name__ == '__main__':
    # check_svi_jw()
    # check_calibrate_svi_jw_1()
    # check_convert_trader_jw_to_original()
    check_get_svi_jw_iv()
    pass