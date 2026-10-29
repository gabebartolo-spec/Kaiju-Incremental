# croc-claw young/exp_set.sh: the four baby g takes (shorter quicker steps, director OK 10-29) replace walk + turns in
# game_out/young/reptilian_baby.kclip (y7; rise_bay and idle_fix1 kept; same-name clips are replaced)
B=C:/kt/casc_drafts_1028/baby; C=C:/Users/DANTE/cascadeur_bridge/croc_new/claw
for spec in "walk_g9 walk 90 walk" "turn_on_the_spot_g9 turn_on_the_spot 109 still" "walk_turn_left_g11 walk_turn_left 91 still" "walk_turn_right_g10 walk_turn_right 91 still"; do
  set -- $spec; echo "== $2 $3 $4 ($1)"; timeout 1800 bash $C/exp_young.sh baby $B/$1.casc $2 0 $3 $4 2>&1 | grep -E "EXPORTED|FAILED|NO BLEND|CLIP |FOOTIK|rror" | cut -c1-260
  sleep 20
done
