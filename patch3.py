with open("z.metatrader/AutoSnD_RiskPanel.mq4", "r", encoding="utf-8") as f:
    text = f.read()

# Fix EnumToString -> GetTFString()
old = "string tfstr=EnumToString((ENUM_TIMEFRAMES)Period());"
new = "string tfstr=GetTFString();"
count = text.count(old)
text = text.replace(old, new)

# Inject GetTFString helper before ExecuteMomentumAutoTrade
helper = (
    'string GetTFString(){\n'
    '   int p=Period();\n'
    '   if(p==1)    return "M1";\n'
    '   if(p==5)    return "M5";\n'
    '   if(p==15)   return "M15";\n'
    '   if(p==30)   return "M30";\n'
    '   if(p==60)   return "H1";\n'
    '   if(p==240)  return "H4";\n'
    '   if(p==1440) return "D1";\n'
    '   if(p==10080)return "W1";\n'
    '   return "MN";\n'
    '}\n\n'
)
text = text.replace("void ExecuteMomentumAutoTrade(", helper + "void ExecuteMomentumAutoTrade(", 1)

with open("z.metatrader/AutoSnD_RiskPanel.mq4", "w", encoding="utf-8") as f:
    f.write(text)

print("Fixed", count, "EnumToString. GetTFString injected.")
