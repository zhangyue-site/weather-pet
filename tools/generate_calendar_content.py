#!/usr/bin/env python3
"""Build deterministic daily programs and Gregorian/lunar lookup data.
Run with lunar_python==1.4.8. App runtime has no Python dependency.
"""
from pathlib import Path
from datetime import date,timedelta
import json,csv
from lunar_python import Solar
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'godot_project/companion/content'
def save(name,data):
 (OUT/name).write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
FAMILIES=[('lantern','灯笼','d54d39','ffd77e'),('firework','烟花','ffbb53','fce8af'),('confetti','彩纸','db5347','ffd568'),('ribbon','绸带','d95477','fbc7a5'),('blossom','花瓣','ee94af','fff2e1'),('leaf','树叶','8bab6d','d5c775'),('snowflake','雪晶','e2f4ff','86c5e3'),('star','星芒','ffd57a','fff0ce'),('heart','爱心','ea8092','ffc8b4'),('butterfly','蝴蝶','b5a4e3','ffe5a2'),('bubble','泡泡','a9e3e2','f8d8ef'),('firefly','萤火','dcdf76','fff6b0'),('raindrop','水珠','8ac9e0','e1f5fb'),('cloud','云朵','f7eee0','c8dce6'),('sun','暖阳','ffcf6c','f9e5a4'),('moon','月华','ecd493','fff1ca'),('kite','纸鸢','6eaca4','edb25d'),('music','音符','9e99d4','eec997'),('lotus','莲花','e4a6b2','b9d4b8'),('candle','烛光','efc075','fff0b0')]
MOTIONS=[('drift','轻落'),('rise','缓升'),('orbit','环绕'),('spiral','旋舞'),('fountain','喷泉'),('burst','绽放'),('wave','波浪'),('cascade','帷幕'),('garland','花环'),('trail','流光')]
effects=[]
for fi,(family,title,a,b) in enumerate(FAMILIES):
 for mi,(motion,mtitle) in enumerate(MOTIONS):
  effects.append({'id':family+'_'+motion,'title':title+'·'+mtitle,'family':family,'motion':motion,'colors':[a,b],'count':12+mi%4*4,'size':5+fi%4,'speed':0.65+mi*0.07})
assert len({(e['family'],e['motion']) for e in effects})==200
save('effects.json',{'schema':1,'effects':effects})
SEASONS=['冬日围炉','早春来信','春风小院','花间漫步','绿荫午后','初夏微光','盛夏清凉','晚夏星河','初秋手记','金秋相伴','晚秋暖意','岁末灯火']
PLANS=[('迎接晨光','stretch'),('窗边听风','idle'),('慢慢喝茶','drink'),('看看小花','water'),('轻轻问好','wave'),('伸展一下','stretch'),('留住微光','idle'),('午后散步','walk'),('捧杯暖手','drink'),('追随云影','notice'),('小小欢呼','celebrate_cheer'),('花下休息','idle'),('向你挥手','wave'),('快乐摇摆','celebrate_dance'),('照看绿植','water'),('安静陪伴','idle'),('散步归来','walk'),('给你祝福','celebrate_wave'),('整理心情','stretch'),('听听院子','notice'),('一起微笑','pet'),('抬头远望','notice'),('喝口水吧','drink'),('伸个懒腰','stretch'),('慢下脚步','walk'),('收集光点','idle'),('转身招呼','wave'),('小院节拍','celebrate_dance'),('留点空闲','idle'),('谢谢今天','celebrate_wave'),('迎接明天','stretch')]
dailies={}
d=date(2000,1,1);index=0
while d.year==2000:
 plan,action=PLANS[d.day-1]
 # Every effect occurs in the annual program; identity includes geometry + motion.
 fx=effects[(index*73)%200]
 dailies[d.strftime('%m-%d')]={'id':'daily_'+d.strftime('%m%d'),'title':SEASONS[d.month-1]+' · '+plan,'caption':f'今天的小计划：{plan}。和你一起，把普通的一天过好。','actions':[action,'idle'],'effect':fx['id'],'kind':'daily','tone':'gentle','priority':0}
 index+=1;d+=timedelta(days=1)
assert len(dailies)==366
save('daily.json',{'schema':1,'days':dailies})
events=[]
def add(i,title,rule,fx,kind='festival',tone='joyful',days=1,priority=70):
 event={'id':i,'title':title,**rule,'days':days,'caption':{'joyful':f'{title}，把今天的祝福送给你。','gentle':f'{title}，今天一起慢慢感受。','solemn':f'{title}，安静致意，珍惜当下。'}[tone], 'actions':['celebrate_wave','celebrate_dance','celebrate_cheer'] if tone=='joyful' else ['idle','notice'], 'effect':fx,'kind':kind,'tone':tone,'priority':priority}
 events.append(event)
add('national_day','欢度国庆',{'month_day':'10-01'},'confetti_burst',days=7,priority=90)
SOLAR=[('new_year','元旦','01-01','firework_burst'),('valentine','情人节','02-14','heart_rise'),('women_day','国际妇女节','03-08','blossom_garland'),('arbor_day','植树节','03-12','leaf_fountain'),('consumer_day','消费者权益日','03-15','star_garland'),('water_day','世界水日','03-22','raindrop_wave'),('meteorology_day','世界气象日','03-23','cloud_drift'),('earth_day','世界地球日','04-22','leaf_orbit'),('book_day','世界读书日','04-23','star_trail'),('labor_day','劳动节','05-01','ribbon_garland'),('youth_day','青年节','05-04','kite_rise'),('nurses_day','国际护士节','05-12','heart_garland'),('museum_day','国际博物馆日','05-18','star_orbit'),('children_day','儿童节','06-01','bubble_fountain'),('environment_day','世界环境日','06-05','leaf_wave'),('oceans_day','世界海洋日','06-08','bubble_wave'),('party_day','建党纪念日','07-01','ribbon_rise'),('army_day','建军节','08-01','star_burst'),('teachers_day','教师节','09-10','blossom_garland'),('peace_day','国际和平日','09-21','cloud_garland'),('older_persons_day','国际老年人日','10-01','heart_garland'),('food_day','世界粮食日','10-16','leaf_cascade'),('un_day','联合国日','10-24','ribbon_orbit'),('halloween','万圣节前夜','10-31','moon_orbit'),('journalists_day','记者节','11-08','music_trail'),('science_day','世界科学日','11-10','star_spiral'),('child_rights_day','世界儿童日','11-20','butterfly_rise'),('volunteer_day','国际志愿者日','12-05','heart_fountain'),('christmas_eve','平安夜','12-24','candle_garland'),('christmas','圣诞节','12-25','snowflake_garland'),('year_end','岁末','12-31','firework_fountain')]
for i,t,md,fx in SOLAR: add(i,t,{'month_day':md},fx,kind='observance' if '世界' in t or '国际' in t else 'festival')
for i,t,md in [('victory','抗战胜利纪念日','09-03'),('martyrs','烈士纪念日','09-30'),('memorial','国家公祭日','12-13')]: add(i,t,{'month_day':md},'candle_garland','memorial','solemn',priority=110)
LUNAR=[('spring_festival','春节','01-01','lantern_garland',7),('lantern_festival','元宵节','01-15','lantern_rise',1),('dragon_head','龙抬头','02-02','kite_spiral',1),('shangsi','上巳节','03-03','blossom_wave',1),('dragon_boat','端午节','05-05','leaf_wave',1),('qixi','七夕','07-07','heart_orbit',1),('mid_autumn','中秋节','08-15','moon_garland',1),('double_ninth','重阳节','09-09','blossom_cascade',1),('laba','腊八节','12-08','sun_garland',1),('little_new_year_north','北方小年','12-23','lantern_wave',1),('little_new_year_south','南方小年','12-24','lantern_wave',1)]
for i,t,md,fx,days in LUNAR: add(i,t,{'lunar_day':md},fx,days=days,priority=85)
add('new_year_eve','除夕',{'lunar_eve':True},'firework_burst',priority=95)
add('mother_day','母亲节',{'week_day':[5,2,0]},'blossom_garland')
add('father_day','父亲节',{'week_day':[6,3,0]},'heart_orbit')
add('thanksgiving','感恩节',{'week_day':[11,4,4]},'leaf_garland')
TERMS='小寒 大寒 立春 雨水 惊蛰 春分 清明 谷雨 立夏 小满 芒种 夏至 小暑 大暑 立秋 处暑 白露 秋分 寒露 霜降 立冬 小雪 大雪 冬至'.split()
TERM_FX=['snowflake','snowflake','blossom','raindrop','butterfly','blossom','candle','raindrop','leaf','leaf','leaf','sun','bubble','bubble','leaf','cloud','raindrop','leaf','moon','snowflake','candle','snowflake','snowflake','lantern']
for i,(term,family) in enumerate(zip(TERMS,TERM_FX)):
 add('term_'+str(i),term,{'solar_term':term},family+'_drift',kind='solar_term',tone='solemn' if term=='清明' else 'gentle',priority=105 if term=='清明' else 40)
save('events.json',{'schema':2,'revision':2,'events':events})
calendar={}
d=date(2025,1,1)
while d<=date(2036,12,31):
 l=Solar.fromYmd(d.year,d.month,d.day).getLunar()
 calendar[d.isoformat()]=[l.getYear(),l.getMonth(),l.getDay(),l.getMonthInChinese()+'月'+l.getDayInChinese(),l.getJieQi()]
 d+=timedelta(days=1)
save('lunar_calendar.json',{'source':'lunar_python 1.4.8 (MIT)','timezone':'Asia/Shanghai','start':'2025-01-01','end':'2036-12-31','days':calendar})
with (ROOT/'docs/calendar/每日内容.csv').open('w') as f:
 w=csv.writer(f);w.writerow(['公历月日','主题','角色动作','特效'])
 for md,p in dailies.items(): w.writerow([md,p['title'],' / '.join(p['actions']),p['effect']])
with (ROOT/'docs/calendar/特效目录.csv').open('w') as f:
 w=csv.writer(f);w.writerow(['ID','名称','图形','运动'])
 for p in effects:w.writerow([p['id'],p['title'],p['family'],p['motion']])
print(json.dumps({'daily':len(dailies),'effects':len(effects),'events':len(events),'lunar_days':len(calendar)},ensure_ascii=False))
