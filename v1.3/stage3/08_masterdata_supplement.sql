-- V1.3 Stage3 补充治理：GMV>=10000 未映射商品人工确认（reviewed_by=MASTERDATA_ADMIN）
BEGIN;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000101', '弹动人参茶树纯露洗发水发膜控油蓬松洗护套装持久留香洗发露推荐', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3775262204530655728', '弹动人参茶树纯露洗发水发膜控油蓬松洗护套装持久留香洗发露推荐', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000101'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000102', '弹动人参茶树纯露发膜控油蓬松持久保湿亮泽养发护发发膜补水洗头', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3657255547859817276', '弹动人参茶树纯露发膜控油蓬松持久保湿亮泽养发护发发膜补水洗头', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000102'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000103', '弹动氨基酸鱼子酱养护丰盈发膜控油蓬松洗发水推荐补水香氛洗发露', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3713519736852709702', '弹动氨基酸鱼子酱养护丰盈发膜控油蓬松洗发水推荐补水香氛洗发露', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000103'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000104', '弹动椰子控油蓬松双0配方养护持久留香柔顺高级洗发膏洗发水推荐T', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3781969689383666101', '弹动椰子控油蓬松双0配方养护持久留香柔顺高级洗发膏洗发水推荐T', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000104'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000105', '弹动鱼子酱氨基酸洗头洗发水发膜洗护套装养护蓬松高级洗发露', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3756014250754179506', '弹动鱼子酱氨基酸洗头洗发水发膜洗护套装养护蓬松高级洗发露', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000105'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000106', '弹动弹动鱼子酱氨基酸洗护套装养护补水控油蓬松洗发水去屑洗发露', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3761941872424124476', '弹动弹动鱼子酱氨基酸洗护套装养护补水控油蓬松洗发水去屑洗发露', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000106'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000107', '弹动鱼子酱氨基酸洗发水+波拉时光沐浴露推荐洗护蓬松护发素留香', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3699812634267353390', '弹动鱼子酱氨基酸洗发水+波拉时光沐浴露推荐洗护蓬松护发素留香', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000107'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000108', '弹动洋甘菊二硫化硒净澈去屑洗发露去屑控油舒缓头痒留香洗发水', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3729110614132523132', '弹动洋甘菊二硫化硒净澈去屑洗发露去屑控油舒缓头痒留香洗发水', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000108'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000109', '弹动多肽生姜控油洗发水发膜套装蓬松控油发膜强韧洗护洗发露D', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3701045682954699023', '弹动多肽生姜控油洗发水发膜套装蓬松控油发膜强韧洗护洗发露D', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000109'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000110', '弹动鱼子酱氨基酸洗发水发膜洗护套装蓬松控油持久留香洗发膏推荐', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3712216044652331033', '弹动鱼子酱氨基酸洗发水发膜洗护套装蓬松控油持久留香洗发膏推荐', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000110'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000111', '弹动人参茶树纯露洗发水发膜控油蓬松持久留香丰盈亮泽洗发露T', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3768285822537826580', '弹动人参茶树纯露洗发水发膜控油蓬松持久留香丰盈亮泽洗发露T', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000111'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000112', '弹动鱼子酱氨基酸洗发水发膜鱼子酱奢护养护蓬松头发洗发露推荐ZC', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3705179438560968743', '弹动鱼子酱氨基酸洗发水发膜鱼子酱奢护养护蓬松头发洗发露推荐ZC', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000112'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000113', '弹动人参茶树纯露洗发水护发素套装控油蓬松防断护留香发膜洗发露', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3656359341075863427', '弹动人参茶树纯露洗发水护发素套装控油蓬松防断护留香发膜洗发露', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000113'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000114', '弹动奢养洗护全家桶鱼子酱人参二硫化硒护发精油套装洗发护发D', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3751757186502624219', '弹动奢养洗护全家桶鱼子酱人参二硫化硒护发精油套装洗发护发D', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000114'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000115', '弹动鱼子酱氨基酸洗发水发膜洗护套装蓬松控油持久留香洗发水T', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3781962349133562210', '弹动鱼子酱氨基酸洗发水发膜洗护套装蓬松控油持久留香洗发水T', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000115'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000116', '【618官方现货】弹动椰子蓬松洗发水柔顺养护控油蓬松留香双0配方ZB', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3790848361658187814', '【618官方现货】弹动椰子蓬松洗发水柔顺养护控油蓬松留香双0配方ZB', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000116'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000117', '弹动鱼子酱氨基酸去屑洗发水推荐洗头膏护发素香氛防干枯控油蓬松', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3549184053443986020', '弹动鱼子酱氨基酸去屑洗发水推荐洗头膏护发素香氛防干枯控油蓬松', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000117'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000118', '弹动香水沐浴露 持久留香深层保湿滋润 润肤香氛', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3714045838092271940', '弹动香水沐浴露 持久留香深层保湿滋润 润肤香氛', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000118'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000119', '弹动鱼子酱人参洗发水发膜洗护套装礼盒装洗发家庭专用留香控油D', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3758177690172129456', '弹动鱼子酱人参洗发水发膜洗护套装礼盒装洗发家庭专用留香控油D', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000119'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000120', '弹动多肽生姜控油洗发水修护养护蓬松防干枯洗头洗发露持久留香', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3713288416415318068', '弹动多肽生姜控油洗发水修护养护蓬松防干枯洗头洗发露持久留香', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000120'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000121', '【会员回购礼】弹动洗发水发膜旅行装柔顺蓬松丰盈控油养护洗发水', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3709424070937411947', '【会员回购礼】弹动洗发水发膜旅行装柔顺蓬松丰盈控油养护洗发水', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000121'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000122', '弹动椰子蓬松洗发水柔顺养护控油蓬松持久留香双0配方洗发推荐ZB', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3648712046603833494', '弹动椰子蓬松洗发水柔顺养护控油蓬松持久留香双0配方洗发推荐ZB', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000122'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000123', '弹动人参茶树纯露蓬松洗头洗发水发膜控油防干枯持久留香洗发露', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3777512887577346091', '弹动人参茶树纯露蓬松洗头洗发水发膜控油防干枯持久留香洗发露', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000123'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000124', '弹动人参茶树纯露洗头洗发水护发发膜去屑控油蓬松洗护套装护发素', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3695874993352212708', '弹动人参茶树纯露洗头洗发水护发发膜去屑控油蓬松洗护套装护发素', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000124'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000125', '弹动鱼子酱氨基酸洗发水人参洗发露发膜持久留香修护柔顺亮泽洗头', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3753211157360542173', '弹动鱼子酱氨基酸洗发水人参洗发露发膜持久留香修护柔顺亮泽洗头', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000125'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000126', '弹动鱼子酱氨基酸控油蓬松洗发水+人参纯露防干枯柔顺洗发露推荐', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3686016419893477823', '弹动鱼子酱氨基酸控油蓬松洗发水+人参纯露防干枯柔顺洗发露推荐', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000126'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000127', '弹动鱼子酱护发精油不黏腻改善毛躁滋养柔顺清爽持久防断留香修护', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3756203886227095924', '弹动鱼子酱护发精油不黏腻改善毛躁滋养柔顺清爽持久防断留香修护', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000127'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000128', '弹动鱼子酱氨基酸洗发水发膜套装控油蓬松香氛洗发水推荐持久留香', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3708857425307238619', '弹动鱼子酱氨基酸洗发水发膜套装控油蓬松香氛洗发水推荐持久留香', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000128'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000129', '弹动人参茶树纯露洗发水发膜控油蓬松洗发露持久防干枯香氛护发素', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3712718416164028597', '弹动人参茶树纯露洗发水发膜控油蓬松洗发露持久防干枯香氛护发素', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000129'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000130', '弹动精粹香水沐浴露持久留香深层保湿滋润润肤香氛ZB', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3704969880672534920', '弹动精粹香水沐浴露持久留香深层保湿滋润润肤香氛ZB', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000130'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000131', '弹动人参茶树纯露洗发水发膜洗护套装控油蓬松持久留香洗发露T', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3809053688601903586', '弹动人参茶树纯露洗发水发膜洗护套装控油蓬松持久留香洗发露T', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000131'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000132', '弹动人参茶树纯露洗发水控油蓬松洗护套装洗发露养发柔顺修护', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3704979428351279153', '弹动人参茶树纯露洗发水控油蓬松洗护套装洗发露养发柔顺修护', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000132'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000133', '弹动鱼子酱氨基酸洗发膏香氛洗发水控油蓬松防干枯洗头洗发水', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3616058573274095640', '弹动鱼子酱氨基酸洗发膏香氛洗发水控油蓬松防干枯洗头洗发水', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000133'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000134', '弹动多肽生姜控油蓬松防干枯发膜洗发水家庭专用持久留香洗发露', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3701046176926269577', '弹动多肽生姜控油蓬松防干枯发膜洗发水家庭专用持久留香洗发露', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000134'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000135', '弹动鱼子酱氨基酸洗护发素洗发水蓬松防干枯控油修护丰盈洗头膏', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3548208612667163091', '弹动鱼子酱氨基酸洗护发素洗发水蓬松防干枯控油修护丰盈洗头膏', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000135'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000136', '【会员兑换礼】弹动氨基酸净澈果酸沐浴露控油清爽润肤嫩肤持久留香', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3639691712936411930', '【会员兑换礼】弹动氨基酸净澈果酸沐浴露控油清爽润肤嫩肤持久留香', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000136'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000137', '弹动人参茶树纯露洗发水发膜套装固发防断头发洗发水洗发膏香氛', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3779734622695457242', '弹动人参茶树纯露洗发水发膜套装固发防断头发洗发水洗发膏香氛', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000137'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000138', '弹动椰子蓬松洗护套装果酸嫩肤沐浴露洗护沐奢护套装持久留香', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3801461556567474477', '弹动椰子蓬松洗护套装果酸嫩肤沐浴露洗护沐奢护套装持久留香', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000138'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000139', '弹动洋甘菊二硫化硒洗发露控油去屑止痒蓬松持久留香洗头洗发水', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 1, '3741516670116691969', '弹动洋甘菊二硫化硒洗发露控油去屑止痒蓬松持久留香洗头洗发水', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000139'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000140', '弹动乳酸菌白松露洗发露去屑控油柔顺香氛亮泽推荐高级洗发水T', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3762142522525221264', '弹动乳酸菌白松露洗发露去屑控油柔顺香氛亮泽推荐高级洗发水T', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000140'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000141', '弹动乳酸菌白松露洗发露  去屑控油柔顺亮泽', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3719080407455629374', '弹动乳酸菌白松露洗发露  去屑控油柔顺亮泽', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000141'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000142', '弹动鱼子酱氨基酸洗发水发膜洗护套装养护蓬松洗发露持久留香T', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3815727195893137557', '弹动鱼子酱氨基酸洗发水发膜洗护套装养护蓬松洗发露持久留香T', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000142'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
INSERT INTO meta.master_product (master_product_code, master_product_name, brand_name, product_status, enabled, notes) VALUES
  ('MP000143', '弹动鱼子酱氨基酸洗发水发膜柔顺蓬松洗头洗发露网红洗发水', '弹动', 'ACTIVE', true, '补充治理：单店高价值商品人工确认') ON CONFLICT (master_product_code) DO NOTHING;
INSERT INTO meta.platform_product_mapping (platform_code, shop_id, platform_product_id, platform_product_name_snapshot, master_product_id, mapping_status, mapping_source, confidence_score, valid_from, enabled, reviewed_by, reviewed_at, notes) VALUES
  ('douyin', 2, '3705303526784762155', '弹动鱼子酱氨基酸洗发水发膜柔顺蓬松洗头洗发露网红洗发水', (SELECT master_product_id FROM meta.master_product WHERE master_product_code='MP000143'), 'CONFIRMED', 'MANUAL', 1.0000, '2026-06-01', true, 'MASTERDATA_ADMIN', now(), '补充治理人工确认') ON CONFLICT DO NOTHING;
COMMIT;