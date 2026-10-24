extends RefCounted
# Shared calendar input, independent choreography; labels match pinned source assets.
const FESTIVALS = {
	"spring_festival": ["舞狮头", "收红包", "写福字", "放烟花", "吃年糕"],
	"new_year_eve": ["写福字", "吃饺子", "舞狮头", "放烟花"],
	"little_new_year_north": ["写福字", "吃糖葫芦", "收红包"],
	"little_new_year_south": ["写福字", "吃年糕", "收红包"],
	"lantern_festival": ["吃汤圆", "舞狮头", "放孔明灯"],
	"dragon_boat": ["吃粽子", "点击回应-开心跃动"],
	"mid_autumn": ["中秋赏月吃月饼", "放孔明灯"],
	"qixi": ["穿针乞巧", "点击回应-开心跃动", "放河灯"],
	"double_ninth": ["插茱萸赏菊", "吃重阳糕", "吃长寿面"],
	"laba": ["吃腊八粥", "点击回应-元气挥手"],
	"shangsi": ["放风筝", "荡秋千", "凭空生花"],
	"dragon_head": ["舞狮头", "吃长寿面"],
	"halloween": ["讨糖南瓜灯", "萌化小幽灵", "被吓一跳"],
	"christmas": ["装点圣诞树", "拆礼物", "小提琴演奏"],
	"christmas_eve": ["装点圣诞树", "悠闲哼歌"],
	"children_day": ["骑木马", "吹气球", "玩水枪", "抽陀螺", "三球抛接"],
	"child_rights_day": ["原地蹲下玩玩具汽车", "吹气球"],
	"arbor_day": ["凭空生花", "蝴蝶蜜蜂环绕头顶开花"],
	"environment_day": ["动物环绕", "凭空生花"],
	"earth_day": ["动物环绕", "蝴蝶蜜蜂环绕头顶开花"],
	"oceans_day": ["蓝鲸现世", "鲸鱼吐泡泡特效", "螃蟹走路"],
	"water_day": ["鲸鱼吐泡泡特效", "东张西望"],
	"food_day": ["吃白饭", "吃午餐"],
	"book_day": ["深度思考碎碎念", "轻快记录"],
	"science_day": ["原地专心玩魔方", "轻快记录"],
	"museum_day": ["东张西望", "轻快记录"],
	"meteorology_day": ["东张西望", "鲸鱼吐泡泡特效"],
	"consumer_day": ["东张西望", "深度思考碎碎念"],
	"journalists_day": ["轻快记录", "写代码"],
	"teachers_day": ["女仆屈膝礼仪", "轻快记录"],
	"nurses_day": ["女仆屈膝礼仪", "点击回应-元气挥手"],
	"older_persons_day": ["吃长寿面", "小提琴演奏"],
	"women_day": ["凭空生花", "小提琴演奏"],
	"mother_day": ["凭空生花", "点击回应-开心跃动"],
	"father_day": ["女仆屈膝礼仪", "点击回应-开心跃动"],
	"thanksgiving": ["女仆屈膝礼仪", "吃晚餐", "点击回应-开心跃动"],
	"volunteer_day": ["碎碎念-擦桌碎碎念", "点击回应-元气挥手"],
	"peace_day": ["放河灯", "悠闲哼歌"],
	"new_year": ["放烟花", "轻快摇摆舞", "拆礼物"],
	"national_day": ["舞狮头", "放烟花", "优雅女仆舞"],
	"party_day": ["舞狮头", "工作状态-雀跃庆祝"],
	"army_day": ["女仆屈膝礼仪", "工作状态-雀跃庆祝"],
	"labor_day": ["碎碎念-擦桌碎碎念", "超大伸懒腰"],
	"youth_day": ["踢毽子", "轻快摇摆舞"],
	"un_day": ["动物环绕", "轻快摇摆舞"],
	"year_end": ["轻快记录", "拆礼物", "放烟花"]
}
const MORNING = ["晨间刷牙", "哈欠连天", "超大伸懒腰", "照镜子", "吃早餐"]
const HOBBIES = ["下五子棋", "原地专心玩魔方", "撸猫", "悠闲哼歌", "吹笛子", "小提琴演奏", "扑克魔术", "三球抛接", "写代码", "轻快记录", "抽陀螺", "踢毽子"]

static func slot(hour: int) -> String:
	if hour < 6 or hour >= 22: return "night"
	if hour < 10: return "morning"
	if hour < 14: return "noon"
	if hour < 18: return "afternoon"
	return "evening"

static func plan(event: Dictionary, date: String, hour: int, environment: Dictionary, variant: int = 0) -> Dictionary:
	var title: String = String(event.get("title", "小院日常"))
	var phase := slot(hour)
	var key := date + ":" + String(event.get("id", "daily")) + ":" + phase
	if event.get("tone", "") == "solemn":
		return {"key":key,"title":title+" · 安静相伴","labels":["待机呼吸休闲", "东张西望"],"reply":"idle","quiet":true}
	if not bool(environment.get("is_day", true)) or phase == "night":
		return {"key":key,"title":"夜深了，一起歇息","labels":["哈欠连天", "原地小憩沉眠"],"reply":"sleep","quiet":true}
	var id: String = String(event.get("id", ""))
	var labels: Array = []
	var reply := "wave"
	if FESTIVALS.has(id):
		var pool: Array = FESTIVALS[id]
		for offset in range(mini(2, pool.size())): labels.append(pool[(variant+offset)%pool.size()])
		reply = "celebrate_cheer" if event.get("kind", "") == "festival" else "wave"
	elif event.get("kind", "") == "anniversary":
		labels = ["拆礼物", "吃长寿面"] if variant%2 == 0 else ["点击回应-开心跃动", "小提琴演奏"]
		reply = "celebrate_wave"
	elif event.get("kind", "") == "solar_term":
		labels = _seasonal(String(event.get("title", "")), environment, variant)
		reply = "notice"
	elif event.get("kind", "daily") != "daily":
		labels = ["女仆屈膝礼仪", "悠闲哼歌"]
	else:
		var day: int = absi(hash(date))
		match phase:
			"morning": labels = [MORNING[(day+variant)%MORNING.size()], "吃早餐"]; reply = "stretch"
			"noon": labels = ["吃午餐", "鲸鱼吐泡泡特效"]; reply = "drink"
			"afternoon": labels = [HOBBIES[(day+variant)%HOBBIES.size()], "蝴蝶蜜蜂环绕头顶开花"]; reply = "water"
			"evening": labels = ["吃晚餐", "悠闲哼歌"]; reply = "drink"
		# Reuse each day's actual theme actions rather than replacing 366 themes with a time-only loop.
		var daily_actions: Array = event.get("actions", [])
		if not daily_actions.is_empty():
			var action: String = String(daily_actions[variant%daily_actions.size()])
			var themed := {"water":"蝴蝶蜜蜂环绕头顶开花", "walk":"螃蟹走路", "notice":"东张西望", "celebrate_dance":"轻快摇摆舞", "celebrate_cheer":"工作状态-雀跃庆祝", "pet":"点击回应-挠痒咯咯笑", "wave":"点击回应-元气挥手", "celebrate_wave":"点击回应-元气挥手"}
			if themed.has(action): labels[1] = themed[action]; reply = action
		if phase == "afternoon":
			var month: int = int(date.substr(5,2))
			if month in [3,4,5] and variant%3 == 0: labels[0] = "放风筝"
			if month in [6,7,8] and variant%3 == 0: labels[0] = "吃西瓜"
			if month in [9,10,11] and variant%3 == 0: labels[0] = "被落叶淹没"
			if month in [12,1,2] and variant%3 == 0: labels[0] = "涮火锅"
	return {"key":key,"title":title,"labels":labels,"reply":reply,"quiet":false}

static func _seasonal(term: String, environment: Dictionary, variant: int) -> Array:
	if term in ["立春","雨水","惊蛰","春分","谷雨"]: return ["放风筝", "凭空生花"] if variant%2 == 0 else ["动物环绕", "蝴蝶蜜蜂环绕头顶开花"]
	if term in ["立夏","小满","芒种","夏至","小暑","大暑"]: return ["吃西瓜", "摇扇纳凉"] if variant%2 == 0 else ["吃冰淇淋融化", "玩水枪"]
	if term in ["立秋","处暑","白露","秋分","寒露","霜降"]: return ["被落叶淹没", "吃大闸蟹"]
	if term == "冬至": return ["吃饺子", "吃汤圆"]
	if String(environment.get("id", "")) in ["snow", "heavy_snow"]: return ["堆雪人", "涮火锅"]
	return ["涮火锅", "悠闲哼歌"]
