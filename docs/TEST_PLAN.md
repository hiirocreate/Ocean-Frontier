# テスト計画 (TEST_PLAN)

## 実行方法
| 種類 | コマンド | 内容 |
|---|---|---|
| 全自動 | `tools/run_tests.sh` | データ検証 → ユニット/統合 → E2E（ヘッドレス）。実行時エラーをログから検出して失敗扱い |
| E2E（描画あり） | `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --script res://tools/smoke_test.gd` | 実シーンでのプレイサイクルとスクリーンショット |
| データ検証のみ | `godot --headless --path . --script res://tools/validate_data.gd` | |

## 自動テスト一覧と状況（2026-10-13 時点：73件 全成功、E2E 31項目 全成功）

### アイテム（仕様45）
| 要件 | テスト | 状況 |
|---|---|---|
| アイテムが正しく追加される | test_inventory::test_add_stackable / test_non_stackable_instances | ✅ |
| 不足時に行動が拒否される | test_actions::test_rejects_when_missing_items | ✅ |
| 成功時に正しい数量が消費される | test_actions::test_expand_raft_consumes_once | ✅ |
| 失敗時に定義どおりの結果になる | test_actions::test_failure_loses_ratio / test_cancel_refunds | ✅ |
| 耐久度ゼロの装備を使用できない | test_inventory::test_broken_tool_unusable_and_repair / test_actions::test_broken_tool_blocks | ✅ |
| 修理が正しく動作する | test_actions::test_repair_action | ✅ |
| 容量を超えて積載できない | test_inventory::test_capacity_limit / test_add_many_is_atomic / test_actions::test_capacity_check / test_data_and_cycle::test_collect_respects_capacity | ✅ |
| 時間のかかる行動の完了時再検証 | test_actions::test_tool_lost_midway_blocks_then_resumes | ✅ |

### セーブ（仕様45）
| 要件 | テスト | 状況 |
|---|---|---|
| 保存とロードが一致する | test_save::test_roundtrip_matches, E2E | ✅ |
| アイテムが二重に増減しない | test_save::test_job_completes_after_load_without_double_consumption | ✅ |
| 抽選結果がセーブと整合 | test_save::test_rng_continuity | ✅ |
| 壊れたデータを検出できる | test_save::test_corrupted_file_detected_and_backup_used / test_garbage_file_fails_safely / test_missing_required_section / test_future_format_rejected | ✅ |
| キャラクターの履歴が維持される | test_crew::test_crew_saved_and_loaded | ✅ |
| ストーリー進行が維持される | flags の保存のみ確認 | 一部 |

### 建築物
| 要件 | テスト | 状況 |
|---|---|---|
| 床の上・空きタイルにのみ設置 | test_buildings::test_building_needs_floor_and_free_tile | ✅ |
| 収納箱で容量増加 | test_build_storage_box_increases_capacity | ✅ |
| 生産・上限・収穫 | test_production_and_harvest, E2E | ✅ |
| 設備が必要なレシピ | test_cook_requires_grill, test_actions::test_facility_required | ✅ |
| 睡眠で疲労回復 | test_sleep_recovers_fatigue | ✅ |
| 建築物のセーブ・ロード | test_buildings_saved_and_loaded | ✅ |
| タップで操作パネル | E2E（描画あり） | ✅ |

### 生存
| 要件 | テスト | 状況 |
|---|---|---|
| 時間経過で空腹・水分が減る | test_survival::test_decay_over_time | ✅ |
| 消耗品で回復する | test_survival::test_use_item_restores | ✅ |
| 不足で効率低下・体力減少 | test_survival::test_starvation_damages_and_efficiency_drops | ✅ |
| 体力0で即ゲームオーバーにならない | test_survival::test_collapse_is_not_game_over | ✅ |

### データ検証（仕様44）
ID重複・存在しないアイテム参照・不正なレシピ・存在しない画像パス・不正な数値 → test_data_and_cycle::test_validator_detects_bad_references ✅

### 最初のプレイ可能サイクル
| 段階 | ユニット（test_first_playable_cycle） | E2E（smoke_test.gd） |
|---|---|---|
| 3Dの海を移動する | 位置の保存のみ | ✅ 入力で筏が移動 |
| 漂流物を回収する | ✅ | ✅ 回収ボタン |
| インベントリに追加する | ✅ | ✅ |
| 必要素材を消費する | ✅ | ✅ |
| 筏を拡張する | ✅ | ✅ タップで位置選択 |
| セーブする | ✅ | ✅ |
| ロードして状態を確認する | ✅ | ✅ 完全一致 |

### 仲間（仕様45）
| 要件 | テスト | 状況 |
|---|---|---|
| 仲間の加入が動作する | test_crew::test_recruit_and_history / test_rescue_dialogue_recruits, E2E | ✅ |
| 加入条件 | test_available_rescues_follow_conditions | ✅ |
| 仕事の割り当てが動作する | test_job_assignment_rules / test_fishing_job_produces_fish / test_construction_speeds_building | ✅ |
| 技能が効率に反映 | test_skill_affects_efficiency | ✅ |
| 関係性が更新される | test_relationship_changes | ✅ |
| 離脱条件が正しく判定される（予兆あり／突然） | test_departure_has_warning_then_leaves_and_stays_in_world / test_sudden_departure_without_warning | ✅ |
| 離脱後も履歴が維持される | 同上 + test_crew_saved_and_loaded | ✅ |
| 再加入 | test_rejoin_conditions | ✅ |
| 会話の条件・既読管理 | test_talk_dialogue_selection | ✅ |
| 主要ストーリーが進行不能にならない | — | フェーズ7で検証 |

### 探索・戦闘
| 要件 | テスト | 状況 |
|---|---|---|
| 海域の判定・移動 | test_zone_detection, E2E | ✅ |
| 地点の発見（隠し地点の条件） | test_site_discovery | ✅ |
| 探索の距離・回数・枯渇 | test_explore_requires_distance_and_depletes | ✅ |
| 潜水の装備・酸素 | test_underwater_requires_gear_and_oxygen | ✅ |
| 初回限定アイテム | test_unique_items_only_first_time | ✅ |
| 消費しない必要アイテム（鍵） | test_keep_items_required_not_consumed | ✅ |
| 勝利・弾薬・摩耗 | test_combat_victory_with_weapon | ✅ |
| 敗北でもゲームオーバーにならない | test_defeat_is_not_game_over | ✅ |
| 壊れた武器・弾なしの銃は使わない | test_broken_weapon_is_skipped | ✅ |
| 交渉の条件 | test_negotiate_requires_bribe | ✅ |
| 捕虜には檻が必要 | test_prisoners_need_prison | ✅ |
| 戦闘状態・発見・評判のセーブ | test_pending_combat_saved | ✅ |

### 勢力・海賊（仕様45）
未実装（フェーズ6）。

## Android テスト（仕様46）
| 項目 | 状況 |
|---|---|
| APK ビルド | ✅ デバッグAPK作成・署名検証済み（arm64-v8a） |
| 起動・タッチ操作・UI・画面サイズ | ⛔ **ブロック中**: 開発環境に KVM がなくエミュレーター不可、実機なし。**実機テスト未実施** |
| セーブ・ロード | PC（Linux）で検証済み。Android 実機未確認 |
| バックグラウンド復帰 | 自動セーブ処理は実装済み・未検証 |
| 長時間プレイ・メモリ | 未実施 |
| 描画品質の切り替え | PC で動作確認（低/中/高） |
| ネットワークなし | ネットワーク権限なしでビルド（INTERNET 権限オフ）。通信処理は存在しない |
