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
echo "=== done ==="
ls "$ASSETS" | grep -c imageset | xargs echo "imagesets:"