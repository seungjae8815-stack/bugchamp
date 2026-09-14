# 보스 44마리 아트 — Gemini 프롬프트 (2026-09-14)

> 난이도마다 보스 10 + 최종보스 1 = 11마리, 네 난이도 44마리. **전부 다른 종**.
> 검증된 순서: ① 대기 원화 1장 → ② 그 그림을 **첨부**하고 3동작 스트립 → ③ 같은 방식으로 나머지 3동작.
> 한 마리 = 이미지 3장. 6동작이 한 장에 나온다.

## 왜 이 순서인가 (한 번 겪은 것)
- 6동작을 한 장에 시키면 모델이 **앞모습·뒷모습 회전표**를 그려 버린다. **한 줄에 3개**가 안전하다.
- "동작 사이를 넓게 띄워라"를 꼭 넣는다. 붙어 있으면 뿔이 옆 동작에 걸려 못 자른다.
- 배경은 **순백색 단색**으로. 빛 번짐·안개·그림자가 들어가면 배경 제거가 지저분해진다.
- 생성 후 저에게 파일을 주시면 제가 잘라서(흰색 키잉) webp 6장으로 만들어 넣습니다.

## 저장 이름 (임시 — 새 구조 id 가 정해지면 제가 옮깁니다)
```
쉬움:   e01 ~ e10, e_final
보통:   n01 ~ n10, n_final
어려움: h01 ~ h10, h_final
극한:   x01 ~ x10, x_final
```
한 마리당 3장: `e01_idle.png`, `e01_strip1.png`(공격준비·공격·피격), `e01_strip2.png`(대기·쓰러지는중·쓰러짐)

---

## 공통 스타일 (모든 프롬프트 끝에 그대로 붙어 있음)
```
Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, clean dark outline, muted earthy palette with one warm accent color, clean readable silhouette, mobile game boss art, high detail. no text, no watermark, no logo, no signature, no UI, no ground shadow.
```

## ① 대기 원화 (비율 1:1)
`{설명}` 자리에 아래 표의 설명을 넣는다.
```
Square 1:1 image. Boss monster: {설명}. Standing in a calm idle pose, side view facing LEFT, full body visible, centered, on a PLAIN FLAT SOLID WHITE background: no scenery, no gradient, no glow, no fog. Crisp clean edges for easy cutout. Style: cozy naturalist cartoon, semi-realistic stylized, soft warm golden-hour lighting, gentle rim light, hand-painted storybook texture, clean dark outline, muted earthy palette with one warm accent color, clean readable silhouette, mobile game boss art, high detail. no text, no watermark, no logo, no signature, no UI, no ground shadow.
```

## ② 스트립 1 — 공격준비 · 공격 · 피격 (비율 3:2, ①의 그림을 첨부)
```
Sprite strip of this exact creature from the attached image: same design, same colors, same painting style. EXACTLY 3 poses side by side in ONE horizontal row, ALL in SIDE VIEW facing LEFT (never front view, never back view), same scale, WIDE EMPTY WHITE GAPS between them, none touching, plain flat solid white background, no ground shadow, no text. Left: attack wind-up, rearing up with its weapon (mandibles / stinger / claws) opening wide. Middle: attack strike, lunging low and forward to the left with the weapon snapped shut. Right: hurt, flinching backward with legs splayed and eyes squinting.
```

## ③ 스트립 2 — 대기 · 쓰러지는 중 · 쓰러짐 (비율 3:2, ①의 그림을 첨부)
```
Sprite strip of this exact creature from the attached image: same design, same colors, same painting style. EXACTLY 3 poses side by side in ONE horizontal row, ALL in SIDE VIEW facing LEFT (never front view, never back view), same scale, WIDE EMPTY WHITE GAPS between them, none touching, plain flat solid white background, no ground shadow, no text. Left: calm idle standing. Middle: collapsing, legs buckling, body sinking toward the ground. Right: defeated, lying flat on its side, weapon slack, eyes dimmed, a few small debris pieces scattered.
```

---

## 쉬움 (e01~e10, e_final) — `{설명}`

| id | 이름 | {설명} |
|---|---|---|
| e01 | 숲의 지배자 | a colossal ancient stag beetle, body armored in mossy oak bark plates, a crown of huge antler-like mandibles, glowing amber eyes, tiny mushrooms and ferns sprouting from its shell |
| e02 | 물가의 포식자 | a giant water scorpion, flat armored brown body glistening wet, long breathing tail, strong raptorial forelegs raised like blades, pale blue-green eyes, water droplets and a reed stuck to its back |
| e03 | 초원의 여왕 | a majestic queen grasshopper, long emerald body with golden wing edges, a crown-like ridge of thorns on her head, powerful spring legs, wildflowers and clover tangled on her back |
| e04 | 밤의 군주 | a huge moth lord, dark velvet wings with pale moon-like eye spots, feathered antennae, soft glowing dust around the wing tips, deep indigo and silver palette |
| e05 | 무쇠턱 폭군 | a brutish rhinoceros beetle tyrant, thick iron-grey armor plates with dents and rust, one massive curved horn, small burning-red eyes, chains and old nails embedded in its shell |
| e06 | 맹독 여제 | an elegant giant wasp empress, slender black body with hazard-yellow stripes, a long glowing green stinger, translucent wings, a thin crown of resin |
| e07 | 그림자 사마귀 | a lean shadow mantis, dark smoky-grey body with violet edges, huge scythe-like forearms, narrow glowing eyes, wisps of shadow trailing from its joints |
| e08 | 심연의 집게왕 | a hulking deep-cave earwig king, glossy black segmented body, enormous pincers at the tail, pale bioluminescent spots along its sides, damp stone dust on its back |
| e09 | 태고의 여왕개미 | a primordial queen ant, vast bronze abdomen with tribal-looking carved markings, thick armored head, a pair of small tattered wings, amber sap crystals growing on her body |
| e10 | 곤충 황제 | an imperial golden scarab, polished gold-and-emerald carapace, a horned ornate head like a crown, jewel-like eyes, faint sun rays engraved on its shell |
| e_final | 태초의 왕충 (최종) | the primordial king of all insects: a titanic ancient beetle-dragon hybrid, layered fossil-stone armor with cracks glowing molten gold, six massive legs, a mane of petrified roots, several horns, eyes like burning suns, clearly larger and more ornate than any other boss |

> 최종보스 ① 프롬프트에는 `Standing in a calm idle pose` 앞에 **"Epic scale, imposing and ornate,"** 를 덧붙인다.

## 보통 (n01~n10, n_final) — 팔레트: 차갑고 짙게, 장식 한 단계 더

| id | 이름 | {설명} |
|---|---|---|
| n01 | 흑요석 사슴벌레 (Obsidian Stag / 黒曜石のクワガタ) | a massive stag beetle armored in glossy black obsidian plates with sharp glassy edges, mandibles like curved blades, cold blue eyes, thin cracks glowing faint blue |
| n02 | 늪지의 잠자리 여왕 (Marsh Dragonfly Queen / 沼地のトンボ女王) | a giant dragonfly queen, long iridescent teal-and-violet body, four wide translucent wings with vein patterns, a crown of woven reeds, water droplets on the wings |
| n03 | 가시 메뚜기 장군 (Thorn Locust General / 棘バッタ将軍) | a war-general locust in bronze plate armor covered in thorns, heavy spring legs with spurs, a cracked shield-like face plate, dull red eyes |
| n04 | 서리 나방 (Frost Moth / 霜の蛾) | a huge pale moth with wings like frosted glass, ice crystals along the wing edges, silver-white fur, soft cold blue glow, breath of frost |
| n05 | 강철 소똥구리 (Steel Dung Beetle / 鋼のフンコロガシ) | a squat, powerful dung beetle plated in riveted steel, pushing a boulder of packed iron ore, thick legs, small determined amber eyes |
| n06 | 개미귀신 함정왕 (Antlion Trapper / 蟻地獄の罠王) | a colossal antlion larva rising from a sand pit, enormous serrated jaws, flat sandy-brown segmented body, grains of sand sliding off its back |
| n07 | 그림자 반딧불 (Shadow Firefly / 影のホタル) | a large firefly with a smoky charcoal body and a lantern abdomen glowing eerie green, translucent dark wings, wisps of light trailing behind |
| n08 | 심해 물장군 (Abyss Giant Water Bug / 深淵のタガメ) | a giant water bug from deep water, flat dark-navy armored body, thick raptorial forelegs, pale bioluminescent spots, faint drifting bubbles |
| n09 | 바위 하늘소 (Granite Longhorn / 花崗岩のカミキリ) | a longhorn beetle with extremely long striped antennae, body plated in grey granite with lichen patches, heavy slow stance, dull green eyes |
| n10 | 황금 장수풍뎅이 (Gilded Hercules / 黄金のヘラクレス) | an imperial hercules beetle with polished gold armor and a massive forked horn, engraved ornaments on the shell, ruby-red eyes |
| n_final | 폭풍의 왕벌 (Storm Hornet King / 嵐の王蜂, 최종) | the storm hornet king: a titanic hornet with jagged black-and-gold armor, wings crackling with lightning, a long glowing stinger, storm clouds swirling around its body, clearly larger and more ornate than any other boss |

## 어려움 (h01~h10, h_final) — 팔레트: 어둡고 뜨겁게(용암·잿빛·핏빛), 장식 많게

| id | 이름 | {설명} |
|---|---|---|
| h01 | 용암 딱정벌레 (Magma Beetle / 溶岩の甲虫) | a heavy beetle with black volcanic-rock armor split by glowing orange magma cracks, smoke rising from its back, molten drips from the mandibles |
| h02 | 검은 사마귀 황후 (Onyx Mantis Empress / 黒瑪瑙のカマキリ皇后) | a tall elegant mantis empress in polished onyx armor with gold trim, enormous scythe arms, a jeweled crown, narrow crimson eyes |
| h03 | 독가시 애벌레 (Venomspine Caterpillar / 毒棘のイモムシ) | a monstrous caterpillar covered in long venomous spines dripping green poison, banded purple-and-black body, many stubby legs, glowing yellow eyes |
| h04 | 잿빛 매미 군주 (Ash Cicada Lord / 灰の蝉主) | a giant cicada with ash-grey armor and cracked translucent wings, embers glowing in the cracks, a crown of burnt twigs, red eyes |
| h05 | 강철 집게벌레 (Iron Earwig / 鉄のハサミムシ) | a long armored earwig with riveted iron plates, gigantic serrated tail pincers held high, sparks at the joints, dull orange eyes |
| h06 | 피의 모기 여왕 (Crimson Mosquito Queen / 紅の蚊女王) | a giant mosquito queen with a crimson glowing abdomen, long needle proboscis, spindly armored legs, translucent red-veined wings |
| h07 | 유령 하루살이 (Phantom Mayfly / 幽霊のカゲロウ) | a ghostly pale mayfly, semi-transparent body with faint blue glow, long trailing tail filaments, wide delicate wings, eyes like dim lanterns |
| h08 | 지옥 개미 군주 (Hellfire Ant Lord / 業火の蟻王) | a massive soldier ant with dark-red chitin, jaws glowing like hot iron, flames flickering from the abdomen, spiked armor plates |
| h09 | 수정 풍뎅이 (Crystal Scarab / 水晶のコガネムシ) | a scarab beetle whose shell is made of translucent violet crystal with light refracting inside, sharp crystal spines, glowing white eyes |
| h10 | 밤의 황제 나방 (Night Emperor Moth / 夜の皇帝蛾) | a colossal emperor moth with deep purple wings bearing golden eye spots, thick black fur, a crown of curved antennae, faint golden dust |
| h_final | 재앙의 대벌레 (Calamity Stick Insect / 災厄のナナフシ, 최종) | the calamity stick insect: an enormous stick insect like a walking dead tree, bark-black body with red glowing veins, spiked limbs, a mane of withered leaves, clearly larger and more ornate than any other boss |

## 극한 (x01~x10, x_final) — 팔레트: 우주·공허(남색·보라·별빛), 장식 최대

| id | 이름 | {설명} |
|---|---|---|
| x01 | 공허 사슴벌레 (Void Stag / 虚空のクワガタ) | a stag beetle whose armor is deep void-black with tiny stars inside, mandibles edged with violet light, eyes like small galaxies |
| x02 | 성운 잠자리 (Nebula Dragonfly / 星雲のトンボ) | a giant dragonfly with wings like painted nebulae in pink, blue and violet, a sleek dark body, trailing stardust |
| x03 | 별빛 반딧불 왕 (Starlight Firefly King / 星光のホタル王) | a regal firefly with a midnight-blue body, an abdomen glowing like a small white star, a crown of light, tiny orbiting sparks |
| x04 | 흑철 장수풍뎅이 (Blacksteel Hercules / 黒鋼のヘラクレス) | a hercules beetle in matte black steel armor with violet edge-light, a colossal serrated horn, engraved runes, pale glowing eyes |
| x05 | 서리 여왕개미 (Frost Ant Queen / 霜の女王蟻) | a vast queen ant made of pale ice and frost, translucent abdomen with frozen eggs inside, crown of icicles, breath of cold mist |
| x06 | 뇌전 말벌 (Thunder Hornet / 雷電の蜂) | a giant hornet with electric-blue stripes, wings crackling with arcs of lightning, a stinger like a lightning rod, storm sparks |
| x07 | 심연의 물방개 (Abyssal Diving Beetle / 深淵のゲンゴロウ) | a sleek diving beetle from the deepest sea, glossy black shell with deep-blue sheen, bioluminescent blue spots, powerful paddle legs |
| x08 | 태양 풍뎅이 (Solar Scarab / 太陽のスカラベ) | a radiant scarab with a shell like the surface of the sun, orange-white glow, solar-flare crest, eyes like white-hot coals |
| x09 | 망령 사마귀 (Wraith Mantis / 亡霊のカマキリ) | a spectral mantis of dark mist and violet light, scythe arms of pale bone-light, eyes like cold flames, tattered ghostly wings |
| x10 | 시간의 매미 (Chrono Cicada / 時の蝉) | an ancient cicada with clockwork-like gold-and-bronze armor, wings etched with rings like tree rings, glowing gear-shaped eyes |
| x_final | 만충의 근원 (The Origin / 万虫の根源, 최종) | the origin of all insects: a titanic primordial mother-insect, body of layered cosmic chitin with galaxies glowing between the plates, dozens of eyes, several pairs of enormous wings, a crown of horns and roots, clearly larger and more ornate than any other boss |
