#!/bin/bash
# Загружает иконки еды из OpenMoji (CC BY-SA 4.0) и собирает Asset Catalog.
# Источник: https://github.com/hfg-gmuend/openmoji
set -u
BASE="https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/618x618"
ASSETS="Resources/Media.xcassets"
mkdir -p "$ASSETS"
printf '{ "info" : { "author" : "xcode", "version" : 1 } }\n' > "$ASSETS/Contents.json"

# foodId -> кодпоинт OpenMoji
foods="
zucchini 1F952
cauliflower 1F96C
broccoli 1F966
pumpkin 1F383
potato 1F954
carrot 1F955
green_peas 1FADB
beet 1FADC
buckwheat 1F35A
rice_porridge 1F35A
corn_porridge 1F33D
oatmeal 1F963
wheat_porridge 1F33E
semolina 1F963
apple 1F34E
pear 1F350
banana 1F34C
prune 1F347
peach 1F351
apricot 1F34A
turkey 1F983
rabbit 1F407
beef 1F356
chicken 1F357
cod 1F41F
hake 1F420
salmon 1F363
cottage_cheese 1F9C0
kefir 1F964
yogurt 1F366
cow_milk 1F95B
egg_yolk 1F373
egg_white 1F95A
peanut 1F95C
tree_nuts 1F330
sesame 1F33F
soy 1FAD8
honey 1F36F
citrus 1F34B
strawberry 1F353
tomato 1F345
eggplant 1F346
bell_pepper 1FAD1
spinach 1F96C
avocado 1F951
sweet_potato 1F360
watermelon 1F349
melon 1F348
grapes 1F347
kiwi 1F95D
mango 1F96D
blueberry 1FAD0
cherry 1F352
pineapple 1F34D
millet_porridge 1F35A
barley_porridge 1F33E
veal 1F969
pork 1F953
lamb 1F356
duck 1F986
pollock 1F41F
shrimp 1F990
mackerel 1F420
cheese 1F9C0
butter 1F9C8
ryazhenka 1F95B
wheat 1F33E
crab 1F980
water 1F4A7
compote 1F9C3
bread 1F35E
olive_oil 1FAD2
"

# реакция -> кодпоинт (экран записи кормления)
reactions="
none 1F44D
skin 1F534
gi 1F922
breathing 1F624
other 2753
"

# оценка вкуса -> кодпоинт
likings="
disliked 1F623
neutral 1F610
liked 1F60B
"

# иконки интерфейса (баннеры, заголовки секций, аватары-заглушки) -> кодпоинт
ui="
chick 1F423
plate 1F37D
warning 26A0
bell 1F514
seedling 1F331
party 1F389
"

# категория -> кодпоинт (фолбэк)
cats="
vegetable 1F955
porridge 1F963
fruit 1F34E
meat 1F356
fish 1F41F
dairy 1F95B
egg 1F95A
allergen 1F95C
other 1F374
"

mk() {
  name="$1"; code="$2"
  dir="$ASSETS/${name}.imageset"
  mkdir -p "$dir"
  if curl -fsSL -o "$dir/icon.png" "$BASE/${code}.png" --max-time 25; then
    printf '{ "images":[{"filename":"icon.png","idiom":"universal"}], "info":{"author":"xcode","version":1} }\n' > "$dir/Contents.json"
    echo "OK   $name ($code)"
  else
    rm -rf "$dir"
    echo "FAIL $name ($code)"
  fi
}

echo "=== foods ==="
while read -r id code; do [ -z "$id" ] && continue; mk "food_$id" "$code"; done <<< "$foods"
echo "=== reactions ==="
while read -r r code; do [ -z "$r" ] && continue; mk "react_$r" "$code"; done <<< "$reactions"
echo "=== likings ==="
while read -r l code; do [ -z "$l" ] && continue; mk "like_$l" "$code"; done <<< "$likings"
echo "=== ui ==="
while read -r u code; do [ -z "$u" ] && continue; mk "ui_$u" "$code"; done <<< "$ui"
echo "=== categories ==="
while read -r c code; do [ -z "$c" ] && continue; mk "cat_$c" "$code"; done <<< "$cats"
# Подборка иконок для выбора при добавлении своего продукта (pick_<кодпоинт>).
picks="1F34E 1F350 1F34A 1F34C 1F349 1F347 1F353 1FAD0 1F352 1F351 1F96D 1F34D 1F95D 1F345 1F346 1F951 1F966 1F96C 1F952 1F33D 1F955 1F9C5 1F954 1F360 1F35E 1F9C0 1F95A 1F357 1F969 1F41F 1F35A 1F35D 1F963 1F372 1F957 1F36E 1F36A 1F9C3 1F95B 1F36F"
echo "=== picks ==="
for code in $picks; do mk "pick_$code" "$code"; done
echo "=== done ==="
ls "$ASSETS" | grep -c imageset | xargs echo "imagesets:"