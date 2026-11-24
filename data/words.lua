-- 70 条词库（来源 4.内容设计.xlsx → 词库）
-- 字母数 = 拼音串长度，由生成脚本算出，不在运行时拼拼音
-- edge：反讽梗，搞笑梗强度「低」时剔除；blocked：脏话缩写，默认屏蔽
return {
    tier_names = {
        T1 = "单键", T2 = "单字/缩写", T3 = "双字词",
        T4 = "短句", T5 = "Boss 长句", T6 = "狂暴长句", T7 = "超长文段",
    },
    -- 未打完的气泡触底按词级扣心态（文档 3 §9）
    tier_damage = { T1 = 5, T2 = 5, T3 = 8, T4 = 10, T5 = 12, T6 = 15, T7 = 15 },
    list = {
        {
            id = "W001", tier = "T1", tier_name = "单键", letters = 1, first_wave = 1,
            text = "（教学）弹幕只显示一个字母", pinyin = "E", retort = "「就这？」",
            edge = false, blocked = false, dmg = 5, note = "教学关用",
        },
        {
            id = "W002", tier = "T2", tier_name = "单字全拼", letters = 2, first_wave = 2,
            text = "急", pinyin = "JI", retort = "「你才急」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W003", tier = "T2", tier_name = "单字全拼", letters = 3, first_wave = 2,
            text = "菜", pinyin = "CAI", retort = "「你才菜」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W004", tier = "T2", tier_name = "单字全拼", letters = 3, first_wave = 2,
            text = "滚", pinyin = "GUN", retort = "「你滚」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W005", tier = "T2", tier_name = "单字全拼", letters = 3, first_wave = 3,
            text = "弱", pinyin = "RUO", retort = "「反弹」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W006", tier = "T2", tier_name = "单字全拼", letters = 4, first_wave = 3,
            text = "杠", pinyin = "GANG", retort = "「杠精本精」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W007", tier = "T2", tier_name = "单字全拼", letters = 4, first_wave = 3,
            text = "酸", pinyin = "SUAN", retort = "「酸死了」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W008", tier = "T2", tier_name = "单字全拼", letters = 6, first_wave = 4,
            text = "装", pinyin = "ZHUANG", retort = "「别装了」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W027", tier = "T2", tier_name = "单字全拼", letters = 4, first_wave = 4,
            text = "呵呵", pinyin = "HEHE", retort = "「呵呵你自己」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W028", tier = "T2", tier_name = "单字全拼", letters = 6, first_wave = 5,
            text = "笑死", pinyin = "XIAOSI", retort = "「笑不完」",
            edge = true, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W029", tier = "T2", tier_name = "单字全拼", letters = 5, first_wave = 5,
            text = "别急", pinyin = "BIEJI", retort = "「我不急」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W030", tier = "T2", tier_name = "单字全拼", letters = 6, first_wave = 5,
            text = "你谁", pinyin = "NISHUI", retort = "「我是你前辈」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W031", tier = "T2", tier_name = "单字全拼", letters = 6, first_wave = 6,
            text = "过时", pinyin = "GUOSHI", retort = "「你才过时」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W032", tier = "T2", tier_name = "单字全拼", letters = 6, first_wave = 6,
            text = "不懂", pinyin = "BUDONG", retort = "「我懂你不懂」",
            edge = false, blocked = false, dmg = 5, note = "",
        },
        {
            id = "W009", tier = "T3", tier_name = "双字词", letters = 6, first_wave = 4,
            text = "就这", pinyin = "JIUZHE", retort = "「就这？」",
            edge = false, blocked = false, dmg = 8, note = "高频梗，建议权重最高",
        },
        {
            id = "W010", tier = "T3", tier_name = "双字词", letters = 6, first_wave = 4,
            text = "取关", pinyin = "QUGUAN", retort = "「取关随意」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W011", tier = "T3", tier_name = "双字词", letters = 6, first_wave = 5,
            text = "破防", pinyin = "POFANG", retort = "「你才破防」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W012", tier = "T3", tier_name = "双字词", letters = 6, first_wave = 5,
            text = "你说", pinyin = "NISHUO", retort = "「我说完了」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W013", tier = "T3", tier_name = "双字词", letters = 6, first_wave = 5,
            text = "我笑", pinyin = "WOXIAO", retort = "「笑不出来了」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W014", tier = "T3", tier_name = "双字词", letters = 4, first_wave = 5,
            text = "服了", pinyin = "FULE", retort = "「不服」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W015", tier = "T3", tier_name = "双字词", letters = 4, first_wave = 6,
            text = "急了", pinyin = "JILE", retort = "「急了急了」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W033", tier = "T3", tier_name = "双字词", letters = 5, first_wave = 6,
            text = "你号", pinyin = "NIHAO", retort = "「你号才没」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W034", tier = "T3", tier_name = "双字词", letters = 7, first_wave = 7,
            text = "演的吧", pinyin = "YANDEBA", retort = "「演给你看」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W035", tier = "T3", tier_name = "双字词", letters = 12, first_wave = 8,
            text = "别带节奏", pinyin = "BIEDAIJIEZOU", retort = "「节奏我带」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W036", tier = "T3", tier_name = "双字词", letters = 8, first_wave = 8,
            text = "蹭热度", pinyin = "CENGREDU", retort = "「热度不够蹭」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W037", tier = "T3", tier_name = "双字词", letters = 14, first_wave = 9,
            text = "你懂个锤子", pinyin = "NIDONGGECHUIZI", retort = "「锤子给你」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W038", tier = "T3", tier_name = "双字词", letters = 7, first_wave = 9,
            text = "已举报", pinyin = "YIJUBAO", retort = "「举报无效」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W039", tier = "T3", tier_name = "双字词", letters = 10, first_wave = 10,
            text = "拉黑不谢", pinyin = "LAHEIBUXIE", retort = "「拉黑请便」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W040", tier = "T3", tier_name = "双字词", letters = 7, first_wave = 10,
            text = "截图了", pinyin = "JIETULE", retort = "「随便截」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W016", tier = "T4", tier_name = "短句", letters = 13, first_wave = 6,
            text = "你行你上", pinyin = "NIXINGNISHANG", retort = "「我不上，我打你」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W017", tier = "T4", tier_name = "短句", letters = 14, first_wave = 7,
            text = "就这水平", pinyin = "JIUZHESHUIPING", retort = "「水平比你高」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W018", tier = "T4", tier_name = "短句", letters = 14, first_wave = 8,
            text = "我玩了二十年", pinyin = "WOWANLESHINIAN", retort = "「二十年白玩」",
            edge = false, blocked = false, dmg = 10, note = "云玩家专属",
        },
        {
            id = "W041", tier = "T4", tier_name = "短句", letters = 11, first_wave = 8,
            text = "谁问你了", pinyin = "SHUIWENNILE", retort = "「我问问你」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W042", tier = "T4", tier_name = "短句", letters = 7, first_wave = 9,
            text = "你也配", pinyin = "NIYEPEI", retort = "「配不配看战绩」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W043", tier = "T4", tier_name = "短句", letters = 7, first_wave = 9,
            text = "别洗了", pinyin = "BIEXILE", retort = "「洗不干净」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W044", tier = "T4", tier_name = "短句", letters = 14, first_wave = 9,
            text = "观众不傻", pinyin = "GUANZHONGBUSHA", retort = "「傻的是你」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W045", tier = "T4", tier_name = "短句", letters = 14, first_wave = 10,
            text = "什么水平", pinyin = "SHENMESHUIPING", retort = "「水平在此」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W046", tier = "T4", tier_name = "短句", letters = 15, first_wave = 10,
            text = "内容空洞", pinyin = "NEIRONGKONGDONG", retort = "「空洞也比你有料」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W047", tier = "T4", tier_name = "短句", letters = 10, first_wave = 10,
            text = "抄袭的吧", pinyin = "CHAOXIDEBA", retort = "「原创在你前面」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W048", tier = "T4", tier_name = "短句", letters = 12, first_wave = 10,
            text = "数据造假", pinyin = "SHUJUZHAOJIA", retort = "「数据在这，自己看」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W049", tier = "T4", tier_name = "短句", letters = 15, first_wave = 11,
            text = "你也太敏感了", pinyin = "NIYETAIMINGANLE", retort = "「敏感的是你」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W050", tier = "T4", tier_name = "短句", letters = 12, first_wave = 11,
            text = "就这心态", pinyin = "JIUZHEXINTAI", retort = "「心态稳如老狗」",
            edge = false, blocked = false, dmg = 10, note = "",
        },
        {
            id = "W019", tier = "T4", tier_name = "短句", letters = 32, first_wave = 12,
            text = "三分钟带你看清真相", pinyin = "SANFENZHONGDAINIKANQINGZHENXIANG", retort = "「不用你看」",
            edge = false, blocked = false, dmg = 10, note = "营销号长句",
        },
        {
            id = "W022", tier = "T4", tier_name = "短句", letters = 30, first_wave = 16,
            text = "你这内容一点价值没有", pinyin = "NIZHENEIRONGYIDIANJIAZHIMEIYOU", retort = "「比你值钱」",
            edge = false, blocked = false, dmg = 10, note = "话题机器人",
        },
        {
            id = "W051", tier = "T5", tier_name = "Boss 长句", letters = 29, first_wave = 14,
            text = "讲得真好下次别讲了", pinyin = "JIANGDEZHENHAOXIACIBIEJIANGLE", retort = "「下次讲到你哑」",
            edge = false, blocked = false, dmg = 12, note = "",
        },
        {
            id = "W052", tier = "T5", tier_name = "Boss 长句", letters = 22, first_wave = 15,
            text = "这条视频我举报了", pinyin = "ZHETIAOSHIPINWOJUBAOLE", retort = "「举报回你」",
            edge = false, blocked = false, dmg = 12, note = "",
        },
        {
            id = "W053", tier = "T5", tier_name = "Boss 长句", letters = 16, first_wave = 16,
            text = "我把你号举报了", pinyin = "WOBANIHAOJUBAOLE", retort = "「你也试试」",
            edge = false, blocked = false, dmg = 12, note = "",
        },
        {
            id = "W054", tier = "T5", tier_name = "Boss 长句", letters = 19, first_wave = 16,
            text = "你的键盘还好吗", pinyin = "NIDEJIANPANHAIHAOMA", retort = "「键盘比你好」",
            edge = false, blocked = false, dmg = 12, note = "",
        },
        {
            id = "W055", tier = "T5", tier_name = "Boss 长句", letters = 17, first_wave = 17,
            text = "评论区已关闭", pinyin = "PINGLUNQUYIGUANBI", retort = "「那我开一个」",
            edge = false, blocked = false, dmg = 12, note = "",
        },
        {
            id = "W020", tier = "T5", tier_name = "Boss 长句", letters = 34, first_wave = 12,
            text = "我粉丝三百万你算什么东西", pinyin = "WOFENSISANBAIWANNISUANSHENMEDONGXI", retort = "「粉丝多不代表对」",
            edge = false, blocked = false, dmg = 12, note = "大V 专属",
        },
        {
            id = "W021", tier = "T5", tier_name = "Boss 长句", letters = 29, first_wave = 12,
            text = "我说的每一句都是为你好", pinyin = "WOSHUODEMEIYIJUDOUSHIWEINIHAO", retort = "「省省吧」",
            edge = false, blocked = false, dmg = 12, note = "大V 阶段技",
        },
        {
            id = "W023", tier = "T5", tier_name = "Boss 长句", letters = 29, first_wave = 21,
            text = "劝你早点删号别丢人了", pinyin = "QUANNIZAODIANSHAHAOBIEDURENLE", retort = "「不删，气死你」",
            edge = false, blocked = false, dmg = 12, note = "镜像号",
        },
        {
            id = "W024", tier = "T5", tier_name = "Boss 长句", letters = 36, first_wave = 24,
            text = "我关注你三年了你就这水平", pinyin = "WOGUANZHUNISANNIENLENIJIUZHESHUIPING", retort = "「三年白关注」",
            edge = false, blocked = false, dmg = 12, note = "",
        },
        {
            id = "W056", tier = "T6", tier_name = "狂暴长句", letters = 27, first_wave = 25,
            text = "我三百万粉丝你算老几", pinyin = "WOSANBAIWANFENSINISUANLAOJI", retort = "「老几不重要」",
            edge = false, blocked = false, dmg = 15, note = "",
        },
        {
            id = "W057", tier = "T6", tier_name = "狂暴长句", letters = 19, first_wave = 26,
            text = "你知道我是谁吗", pinyin = "NIZHIDAOWOSHISHUIMA", retort = "「知道，一个号」",
            edge = false, blocked = false, dmg = 15, note = "",
        },
        {
            id = "W058", tier = "T6", tier_name = "狂暴长句", letters = 20, first_wave = 27,
            text = "平台是我家开的", pinyin = "PINGTAISHIWOJIAKAIDE", retort = "「那你关了吧」",
            edge = false, blocked = false, dmg = 15, note = "",
        },
        {
            id = "W059", tier = "T6", tier_name = "狂暴长句", letters = 30, first_wave = 28,
            text = "我的律师函已经在路上了", pinyin = "WODELVSHIHANYIJINGZAILUSHANGLE", retort = "「我等着」",
            edge = false, blocked = false, dmg = 15, note = "",
        },
        {
            id = "W060", tier = "T6", tier_name = "狂暴长句", letters = 27, first_wave = 28,
            text = "全网都在等你道歉", pinyin = "QUANWANGDOUZAIDENGNIDAOQIAN", retort = "「等不到」",
            edge = false, blocked = false, dmg = 15, note = "",
        },
        {
            id = "W025", tier = "T6", tier_name = "狂暴长句", letters = 37, first_wave = 28,
            text = "你说的每一句话我都截图了等着吧", pinyin = "NISHUODEMEIYIJUHUADOUJIETULEDENGZHEBA", retort = "「随便截」",
            edge = false, blocked = false, dmg = 15, note = "超级大V 阶段技",
        },
        {
            id = "W026", tier = "T6", tier_name = "狂暴长句", letters = 42, first_wave = 29,
            text = "全网都在转你的黑料你还嘴硬", pinyin = "QUANWANGDOUZAIZHUANNIDEHEILIAONIHAIZUIYING", retort = "「黑料随便查」",
            edge = false, blocked = false, dmg = 15, note = "网暴巨兽",
        },
        {
            id = "W061", tier = "T7", tier_name = "超长文段", letters = 51, first_wave = 46,
            text = "我说的每句话都是为你好你怎么就不明白呢", pinyin = "WOSHUODEMEIJUHUADOUSHIWEINIHAONIZENMEJIUBUMINGBAINE", retort = "「明白，但我不听」",
            edge = false, blocked = false, dmg = 15, note = "46 波后专用",
        },
        {
            id = "W062", tier = "T7", tier_name = "超长文段", letters = 54, first_wave = 46,
            text = "你这种人也就只能在网上敲敲键盘了", pinyin = "NIZHEZHONGRENYEJIUZHINENGZAIWANGSHANGQIAOQIAOJIANPANLE", retort = "「键盘也能敲碎你」",
            edge = false, blocked = false, dmg = 15, note = "46 波后专用",
        },
        {
            id = "W063", tier = "T2", tier_name = "单字全拼", letters = 4, first_wave = 3,
            text = "典", pinyin = "DIAN", retort = "「不典，原创」",
            edge = true, blocked = false, dmg = 5, note = "单字梗，短平快，适合高频穿插",
        },
        {
            id = "W064", tier = "T2", tier_name = "单字全拼", letters = 4, first_wave = 4,
            text = "孝", pinyin = "XIAO", retort = "「孝完了」",
            edge = true, blocked = false, dmg = 5, note = "单字梗，反讽味最重",
        },
        {
            id = "W065", tier = "T2", tier_name = "单字全拼", letters = 4, first_wave = 5,
            text = "绷", pinyin = "BENG", retort = "「绷不住了是吧」",
            edge = true, blocked = false, dmg = 5, note = "单字梗，配合「笑死」出现",
        },
        {
            id = "W066", tier = "T3", tier_name = "双字词", letters = 6, first_wave = 6,
            text = "笑了", pinyin = "XIAOLE", retort = "「笑你自己」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W067", tier = "T3", tier_name = "双字词", letters = 6, first_wave = 8,
            text = "力工", pinyin = "LIGONG", retort = "「力工也比你强」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W068", tier = "T3", tier_name = "双字词", letters = 7, first_wave = 9,
            text = "刀工", pinyin = "DAOGONG", retort = "「刀工切你」",
            edge = false, blocked = false, dmg = 8, note = "",
        },
        {
            id = "W069", tier = "T2", tier_name = "字母缩写", letters = 3, first_wave = 20,
            text = "cnm", pinyin = "CNM", retort = "「字母还你」",
            edge = false, blocked = true, dmg = 5, note = "纯字母缩写梗；平台审核高风险，见备注",
        },
        {
            id = "W070", tier = "T2", tier_name = "字母缩写", letters = 4, first_wave = 22,
            text = "nmsl", pinyin = "NMSL", retort = "「原样还给你」",
            edge = false, blocked = true, dmg = 5, note = "纯字母缩写梗；平台审核高风险，见备注",
        },
    },
}
