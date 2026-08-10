--
-- PostgreSQL database dump
--

-- Dumped from database version 16.6
-- Dumped by pg_dump version 16.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: shop; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.shop (
    shop_id bigint NOT NULL,
    platform_code character varying(30) NOT NULL,
    shop_code character varying(50) NOT NULL,
    shop_name character varying(100) NOT NULL,
    platform_shop_id character varying(100),
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE meta.shop OWNER TO postgres;

--
-- Name: TABLE shop; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.shop IS '店铺基础资料表：统一登记抖音、天猫、京东等平台的所有店铺。';


--
-- Name: COLUMN shop.shop_id; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.shop_id IS '店铺内部ID：数据库自动生成的唯一编号。';


--
-- Name: COLUMN shop.platform_code; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.platform_code IS '平台编码：例如douyin代表抖音，tmall代表天猫，jd代表京东。';


--
-- Name: COLUMN shop.shop_code; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.shop_code IS '店铺内部编码：企业自己制定的稳定店铺编码，不随店铺名称变化。';


--
-- Name: COLUMN shop.shop_name; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.shop_name IS '店铺名称：平台上显示的正式店铺名称。';


--
-- Name: COLUMN shop.platform_shop_id; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.platform_shop_id IS '平台店铺ID：抖音、天猫等平台提供的店铺唯一编号，没有时可以暂时为空。';


--
-- Name: COLUMN shop.enabled; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.enabled IS '是否启用：TRUE表示正常使用，FALSE表示停止导入和查询。';


--
-- Name: COLUMN shop.created_at; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.created_at IS '创建时间：店铺资料写入数据库的时间。';


--
-- Name: metric_formula_rule; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.metric_formula_rule (
    metric_rule_id bigint NOT NULL,
    target_schema character varying(50) DEFAULT 'core'::character varying NOT NULL,
    target_table character varying(100) NOT NULL,
    target_column_name_cn character varying(300) NOT NULL,
    target_column_name character varying(150) NOT NULL,
    metric_category character varying(50) NOT NULL,
    calculation_mode character varying(30) NOT NULL,
    formula_cn text,
    numerator_expression text,
    denominator_expression text,
    multiplier numeric(20,8) DEFAULT 1 NOT NULL,
    single_row_formula text,
    period_formula_sql text,
    zero_denominator_rule character varying(30) DEFAULT 'NULL'::character varying NOT NULL,
    cross_period_recalculable boolean DEFAULT false NOT NULL,
    auto_use_allowed boolean DEFAULT false NOT NULL,
    rule_status character varying(30) NOT NULL,
    display_format character varying(30),
    mapping_version character varying(20) DEFAULT 'V1.4'::character varying NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    verification_method text,
    verification_period character varying(100),
    verification_result text
);


ALTER TABLE meta.metric_formula_rule OWNER TO postgres;

--
-- Name: TABLE metric_formula_rule; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.metric_formula_rule IS 'V1.4指标公式规则：记录比例/均值等非可加指标的分子、分母、跨期SQL、规则状态及真实Excel核对结果。';


--
-- Name: COLUMN metric_formula_rule.target_schema; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.target_schema IS '目标Schema，当前为core。';


--
-- Name: COLUMN metric_formula_rule.target_table; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.target_table IS '目标正式表。';


--
-- Name: COLUMN metric_formula_rule.target_column_name_cn; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.target_column_name_cn IS '指标中文名称。';


--
-- Name: COLUMN metric_formula_rule.target_column_name; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.target_column_name IS '指标英文物理字段名。';


--
-- Name: COLUMN metric_formula_rule.metric_category; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.metric_category IS '指标类别：比例指标或均值指标。';


--
-- Name: COLUMN metric_formula_rule.calculation_mode; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.calculation_mode IS '计算模式：ratio、ratio_x1000、ratio_expr或source_only。';


--
-- Name: COLUMN metric_formula_rule.formula_cn; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.formula_cn IS '业务公式中文说明。';


--
-- Name: COLUMN metric_formula_rule.numerator_expression; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.numerator_expression IS '分子字段或分子表达式。';


--
-- Name: COLUMN metric_formula_rule.denominator_expression; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.denominator_expression IS '分母字段或表达式。';


--
-- Name: COLUMN metric_formula_rule.multiplier; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.multiplier IS '计算倍率，例如千次曝光指标为1000。';


--
-- Name: COLUMN metric_formula_rule.single_row_formula; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.single_row_formula IS '单行英文公式；source_only或缺基础字段时为空。';


--
-- Name: COLUMN metric_formula_rule.period_formula_sql; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.period_formula_sql IS '跨期聚合SQL表达式；禁止简单SUM/AVG非可加指标。';


--
-- Name: COLUMN metric_formula_rule.zero_denominator_rule; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.zero_denominator_rule IS '分母为0规则，统一为NULL。';


--
-- Name: COLUMN metric_formula_rule.cross_period_recalculable; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.cross_period_recalculable IS '当前正式表是否具备完整基础字段，可精确跨期重算。';


--
-- Name: COLUMN metric_formula_rule.auto_use_allowed; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.auto_use_allowed IS '是否允许后续mart/MCP自动采用该规则。';


--
-- Name: COLUMN metric_formula_rule.rule_status; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.rule_status IS '当前状态：已确认、已明确、待平台口径确认或缺基础字段。';


--
-- Name: COLUMN metric_formula_rule.display_format; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.display_format IS '展示格式；比例指标通常为0.00%。';


--
-- Name: COLUMN metric_formula_rule.mapping_version; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.mapping_version IS '规则版本。';


--
-- Name: COLUMN metric_formula_rule.notes; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.notes IS '补充业务说明。';


--
-- Name: COLUMN metric_formula_rule.verification_method; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.verification_method IS '公式确认方式，例如真实6月Excel逐行反算核对。';


--
-- Name: COLUMN metric_formula_rule.verification_period; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.verification_period IS '公式核对样本期间。';


--
-- Name: COLUMN metric_formula_rule.verification_result; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.verification_result IS '公式核对结果。';


--
-- Name: database_object_dictionary; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.database_object_dictionary (
    dictionary_id bigint NOT NULL,
    schema_name character varying(50) NOT NULL,
    object_name character varying(150) NOT NULL,
    object_type character varying(30) DEFAULT 'table'::character varying NOT NULL,
    object_name_cn character varying(200),
    column_name character varying(150),
    column_name_cn character varying(300),
    source_platform character varying(50) DEFAULT 'douyin'::character varying,
    source_sheet_name character varying(200),
    source_field_name_cn character varying(300),
    source_header_variants jsonb,
    chinese_name_source character varying(40) DEFAULT 'source_header'::character varying NOT NULL,
    name_resolution_status character varying(40) DEFAULT 'unique_source_header'::character varying NOT NULL,
    is_manual_override boolean DEFAULT false NOT NULL,
    override_reason text,
    business_definition text,
    display_order integer,
    visible_in_cn_view boolean DEFAULT true NOT NULL,
    mapping_version character varying(20) DEFAULT 'V1.1'::character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE meta.database_object_dictionary OWNER TO postgres;

--
-- Name: TABLE database_object_dictionary; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.database_object_dictionary IS '全库中英文字典：记录最终显示名称及其来源（原始表头/系统词典/人工覆盖），可溯源。';


--
-- Name: COLUMN database_object_dictionary.source_header_variants; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.database_object_dictionary.source_header_variants IS '同一物理字段对应的所有“工作表→原始表头”，JSONB保留多源信息。';


--
-- Name: COLUMN database_object_dictionary.chinese_name_source; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.database_object_dictionary.chinese_name_source IS '名称来源：source_header原始表头/manual人工/system_dictionary系统词典/comment注释。';


--
-- Name: COLUMN database_object_dictionary.name_resolution_status; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.database_object_dictionary.name_resolution_status IS '解析状态：unique_source_header唯一表头/manual_confirmed人工确认/system_field系统字段/conflict_pending冲突待决。';


--
-- Name: database_object_dictionary_dictionary_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.database_object_dictionary_dictionary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.database_object_dictionary_dictionary_id_seq OWNER TO postgres;

--
-- Name: database_object_dictionary_dictionary_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.database_object_dictionary_dictionary_id_seq OWNED BY meta.database_object_dictionary.dictionary_id;


--
-- Name: field_mapping; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.field_mapping (
    mapping_id bigint NOT NULL,
    source_sheet_name character varying(100) NOT NULL,
    source_sheet_code character varying(100) NOT NULL,
    source_column_order integer NOT NULL,
    source_column_name character varying(300) NOT NULL,
    target_schema character varying(50) DEFAULT 'core'::character varying NOT NULL,
    target_table character varying(100) NOT NULL,
    target_column_name character varying(150) NOT NULL,
    target_column_name_cn character varying(300) NOT NULL,
    target_data_type character varying(100) NOT NULL,
    field_category character varying(50) NOT NULL,
    aggregation_rule character varying(200) NOT NULL,
    transform_rule text,
    value_unit character varying(30) DEFAULT 'number'::character varying NOT NULL,
    display_format character varying(30),
    display_decimal_places smallint,
    is_business_key boolean DEFAULT false NOT NULL,
    is_required_header boolean DEFAULT true NOT NULL,
    mapping_version character varying(20) DEFAULT 'V1.1'::character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE meta.field_mapping OWNER TO postgres;

--
-- Name: TABLE field_mapping; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.field_mapping IS '字段映射表：逐字段记录11张源工作表的中文字段如何转换为正式表英文列、数据类型、聚合规则和清洗规则。';


--
-- Name: COLUMN field_mapping.mapping_id; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.mapping_id IS '字段映射ID：数据库自动生成。';


--
-- Name: COLUMN field_mapping.source_sheet_name; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.source_sheet_name IS '源工作表中文名称。';


--
-- Name: COLUMN field_mapping.source_sheet_code; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.source_sheet_code IS '源工作表英文编码。';


--
-- Name: COLUMN field_mapping.source_column_order; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.source_column_order IS '源字段顺序：从1开始，用于严格校验表头顺序。';


--
-- Name: COLUMN field_mapping.source_column_name; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.source_column_name IS '源Excel中文字段名。';


--
-- Name: COLUMN field_mapping.target_schema; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.target_schema IS '目标Schema。';


--
-- Name: COLUMN field_mapping.target_table; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.target_table IS '目标正式表。';


--
-- Name: COLUMN field_mapping.target_column_name; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.target_column_name IS '目标英文物理字段名。';


--
-- Name: COLUMN field_mapping.target_column_name_cn; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.target_column_name_cn IS '目标字段中文名称。';


--
-- Name: COLUMN field_mapping.target_data_type; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.target_data_type IS 'PostgreSQL目标数据类型。';


--
-- Name: COLUMN field_mapping.field_category; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.field_category IS '字段类别：日期、维度、标识、可累加金额、可累加计数、均值或比例。';


--
-- Name: COLUMN field_mapping.aggregation_rule; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.aggregation_rule IS '跨日期汇总规则；比例和均值禁止直接求和或简单平均。';


--
-- Name: COLUMN field_mapping.transform_rule; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.transform_rule IS '导入时的数据清洗和类型转换规则。';


--
-- Name: COLUMN field_mapping.value_unit; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.value_unit IS '数值单位：number普通数值、percent百分比。比例指标保存比率原始数值，不限制0—1；数值型源值原样保留。';


--
-- Name: COLUMN field_mapping.display_format; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.display_format IS '展示格式：百分比指标统一使用0.00%，例如数据库值0.0378展示为3.78%。';


--
-- Name: COLUMN field_mapping.display_decimal_places; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.display_decimal_places IS '展示小数位数：百分比指标固定为2。';


--
-- Name: COLUMN field_mapping.is_business_key; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.is_business_key IS '是否属于该正式表业务唯一键。';


--
-- Name: COLUMN field_mapping.is_required_header; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.is_required_header IS '源文件是否必须存在该字段表头。';


--
-- Name: COLUMN field_mapping.mapping_version; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.mapping_version IS '字段映射版本。';


--
-- Name: COLUMN field_mapping.enabled; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.enabled IS '是否启用该字段。';


--
-- Name: COLUMN field_mapping.notes; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.notes IS '补充说明。';


--
-- Name: COLUMN field_mapping.created_at; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.created_at IS '映射记录创建时间。';


--
-- Name: field_mapping_mapping_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.field_mapping_mapping_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.field_mapping_mapping_id_seq OWNER TO postgres;

--
-- Name: field_mapping_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.field_mapping_mapping_id_seq OWNED BY meta.field_mapping.mapping_id;


--
-- Name: metric_formula_rule_metric_rule_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.metric_formula_rule_metric_rule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.metric_formula_rule_metric_rule_id_seq OWNER TO postgres;

--
-- Name: metric_formula_rule_metric_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.metric_formula_rule_metric_rule_id_seq OWNED BY meta.metric_formula_rule.metric_rule_id;


--
-- Name: shop_shop_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.shop_shop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.shop_shop_id_seq OWNER TO postgres;

--
-- Name: shop_shop_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.shop_shop_id_seq OWNED BY meta.shop.shop_id;


--
-- Name: database_object_dictionary dictionary_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.database_object_dictionary ALTER COLUMN dictionary_id SET DEFAULT nextval('meta.database_object_dictionary_dictionary_id_seq'::regclass);


--
-- Name: field_mapping mapping_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping ALTER COLUMN mapping_id SET DEFAULT nextval('meta.field_mapping_mapping_id_seq'::regclass);


--
-- Name: metric_formula_rule metric_rule_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.metric_formula_rule ALTER COLUMN metric_rule_id SET DEFAULT nextval('meta.metric_formula_rule_metric_rule_id_seq'::regclass);


--
-- Name: shop shop_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.shop ALTER COLUMN shop_id SET DEFAULT nextval('meta.shop_shop_id_seq'::regclass);


--
-- Data for Name: database_object_dictionary; Type: TABLE DATA; Schema: meta; Owner: postgres
--

COPY meta.database_object_dictionary (dictionary_id, schema_name, object_name, object_type, object_name_cn, column_name, column_name_cn, source_platform, source_sheet_name, source_field_name_cn, source_header_variants, chinese_name_source, name_resolution_status, is_manual_override, override_reason, business_definition, display_order, visible_in_cn_view, mapping_version, enabled, created_at, updated_at) FROM stdin;
489	core	douyin_deal_daily	table	抖音成交日报	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
548	core	douyin_carrier_daily	table	抖音载体日报	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
619	core	douyin_account_daily	table	抖音账号日报	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
690	core	douyin_content_daily	table	抖音内容日报	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
761	core	douyin_terminal_daily	table	抖音终端日报	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
805	core	douyin_category_daily	table	抖音类目日报	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
822	core	douyin_product_daily	table	抖音商品日报	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
842	core	douyin_price_band_daily	table	抖音价格带日报	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
854	core	douyin_audience_daily	table	抖音人群日报	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
869	meta	shop	table	店铺信息	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
877	meta	source_sheet_mapping	table	工作表映射规则	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
891	meta	field_mapping	table	字段映射规则	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
914	meta	metric_formula_rule	table	指标公式规则	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
939	meta	database_object_dictionary	table	数据库中英文字典	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
962	audit	import_batch	table	导入批次记录	\N	\N	douyin	\N	\N	\N	manual	manual_confirmed	f	\N	\N	\N	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
871	meta	shop	column	\N	platform_code	平台编码	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
872	meta	shop	column	\N	shop_code	店铺编码	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
873	meta	shop	column	\N	shop_name	店铺名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
874	meta	shop	column	\N	platform_shop_id	平台店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
870	meta	shop	column	\N	shop_id	店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
875	meta	shop	column	\N	enabled	是否启用	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
876	meta	shop	column	\N	created_at	创建时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
965	audit	import_batch	column	\N	shop_id	店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
964	audit	import_batch	column	\N	platform_code	平台编码	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
966	audit	import_batch	column	\N	source_file_name	源文件名	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
967	audit	import_batch	column	\N	source_file_path	源文件路径	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
968	audit	import_batch	column	\N	file_sha256	文件SHA256	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
969	audit	import_batch	column	\N	period_start	周期开始	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
970	audit	import_batch	column	\N	period_end	周期结束	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
975	audit	import_batch	column	\N	error_message	错误信息	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
963	audit	import_batch	column	\N	batch_id	导入批次ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
971	audit	import_batch	column	\N	import_mode	导入模式	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
972	audit	import_batch	column	\N	import_status	导入状态	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
973	audit	import_batch	column	\N	source_row_count	源文件行数	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
974	audit	import_batch	column	\N	inserted_row_count	写入行数	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
976	audit	import_batch	column	\N	imported_at	写入时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
878	meta	source_sheet_mapping	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
880	meta	source_sheet_mapping	column	\N	source_sheet_code	工作表编码	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
882	meta	source_sheet_mapping	column	\N	target_table	目标正式表	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
883	meta	source_sheet_mapping	column	\N	sale_scope_override	成交范围覆盖值	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
884	meta	source_sheet_mapping	column	\N	expected_column_count	预期字段数	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
885	meta	source_sheet_mapping	column	\N	sample_row_count	参考样表行数	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
886	meta	source_sheet_mapping	column	\N	load_order	导入顺序	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
889	meta	source_sheet_mapping	column	\N	description	说明	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
879	meta	source_sheet_mapping	column	\N	source_report_code	源报表编码	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
881	meta	source_sheet_mapping	column	\N	target_schema	目标Schema	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
887	meta	source_sheet_mapping	column	\N	mapping_version	映射版本	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
888	meta	source_sheet_mapping	column	\N	enabled	是否启用	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
890	meta	source_sheet_mapping	column	\N	created_at	创建时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
893	meta	field_mapping	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
894	meta	field_mapping	column	\N	source_sheet_code	工作表编码	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
895	meta	field_mapping	column	\N	source_column_order	源字段顺序	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
896	meta	field_mapping	column	\N	source_column_name	源中文字段名	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
898	meta	field_mapping	column	\N	target_table	目标正式表	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
899	meta	field_mapping	column	\N	target_column_name	目标英文字段名	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
900	meta	field_mapping	column	\N	target_column_name_cn	目标字段中文名	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
901	meta	field_mapping	column	\N	target_data_type	目标数据类型	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
902	meta	field_mapping	column	\N	field_category	字段类别	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
903	meta	field_mapping	column	\N	aggregation_rule	聚合规则	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
904	meta	field_mapping	column	\N	transform_rule	转换规则	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
906	meta	field_mapping	column	\N	display_format	展示格式	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	15	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
907	meta	field_mapping	column	\N	display_decimal_places	展示小数位	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	16	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
912	meta	field_mapping	column	\N	notes	备注	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	21	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
892	meta	field_mapping	column	\N	mapping_id	mapping_id	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
897	meta	field_mapping	column	\N	target_schema	目标Schema	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
905	meta	field_mapping	column	\N	value_unit	数值单位	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
908	meta	field_mapping	column	\N	is_business_key	业务键标记	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	17	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
909	meta	field_mapping	column	\N	is_required_header	必填表头标记	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	18	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
910	meta	field_mapping	column	\N	mapping_version	映射版本	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	19	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
911	meta	field_mapping	column	\N	enabled	是否启用	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	20	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
913	meta	field_mapping	column	\N	created_at	创建时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	22	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
491	core	douyin_deal_daily	column	\N	shop_id	店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
492	core	douyin_deal_daily	column	\N	biz_date	日期	douyin	\N	\N	{"合作成交": "日期", "成交概览": "日期", "自营成交": "日期"}	source_header	unique_source_header	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
493	core	douyin_deal_daily	column	\N	sale_scope	成交范围	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
496	core	douyin_deal_daily	column	\N	user_pay_amount	用户支付金额	douyin	\N	\N	{"合作成交": "用户支付金额", "成交概览": "用户支付金额", "自营成交": "用户支付金额"}	source_header	unique_source_header	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
497	core	douyin_deal_daily	column	\N	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	douyin	\N	\N	{"合作成交": "退款后用户支付金额(支付时间)", "成交概览": "退款后用户支付金额(支付时间)", "自营成交": "退款后用户支付金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
498	core	douyin_deal_daily	column	\N	smart_coupon_amount	智能优惠券金额	douyin	\N	\N	{"合作成交": "智能优惠券金额", "成交概览": "智能优惠券金额", "自营成交": "智能优惠券金额"}	source_header	unique_source_header	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
499	core	douyin_deal_daily	column	\N	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	douyin	\N	\N	{"合作成交": "退款后智能优惠券金额(支付时间)", "成交概览": "退款后智能优惠券金额(支付时间)", "自营成交": "退款后智能优惠券金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
500	core	douyin_deal_daily	column	\N	platform_subsidy_amount	平台补贴金额	douyin	\N	\N	{"合作成交": "平台补贴金额", "成交概览": "平台补贴金额", "自营成交": "平台补贴金额"}	source_header	unique_source_header	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
501	core	douyin_deal_daily	column	\N	transaction_order_count	成交订单数	douyin	\N	\N	{"合作成交": "成交订单数", "成交概览": "成交订单数", "自营成交": "成交订单数"}	source_header	unique_source_header	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
502	core	douyin_deal_daily	column	\N	transaction_buyer_count	成交人数	douyin	\N	\N	{"合作成交": "成交人数", "成交概览": "成交人数", "自营成交": "成交人数"}	source_header	unique_source_header	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
503	core	douyin_deal_daily	column	\N	avg_customer_amount	客单价	douyin	\N	\N	{"合作成交": "客单价", "成交概览": "客单价", "自营成交": "客单价"}	source_header	unique_source_header	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
504	core	douyin_deal_daily	column	\N	transaction_amount	成交金额	douyin	\N	\N	{"合作成交": "成交金额", "成交概览": "成交金额", "自营成交": "成交金额"}	source_header	unique_source_header	f	\N	\N	15	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
505	core	douyin_deal_daily	column	\N	net_transaction_amount	净成交金额	douyin	\N	\N	{"合作成交": "净成交金额", "成交概览": "净成交金额", "自营成交": "净成交金额"}	source_header	unique_source_header	f	\N	\N	16	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
506	core	douyin_deal_daily	column	\N	refund_amount_refund_time	退款金额(退款时间)	douyin	\N	\N	{"合作成交": "退款金额(退款时间)", "成交概览": "退款金额(退款时间)", "自营成交": "退款金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	17	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
507	core	douyin_deal_daily	column	\N	transaction_refund_amount_refund_time	成交退款金额(退款时间)	douyin	\N	\N	{"合作成交": "成交退款金额(退款时间)", "成交概览": "成交退款金额(退款时间)", "自营成交": "成交退款金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	18	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
508	core	douyin_deal_daily	column	\N	refund_order_count_refund_time	退款订单数(退款时间)	douyin	\N	\N	{"合作成交": "退款订单数(退款时间)", "成交概览": "退款订单数(退款时间)", "自营成交": "退款订单数(退款时间)"}	source_header	unique_source_header	f	\N	\N	19	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
509	core	douyin_deal_daily	column	\N	refund_rate_pay_time	退款率(支付时间)	douyin	\N	\N	{"合作成交": "退款率(支付时间)", "成交概览": "退款率(支付时间)", "自营成交": "退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	20	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
510	core	douyin_deal_daily	column	\N	refund_amount_pay_time	退款金额(支付时间)	douyin	\N	\N	{"合作成交": "退款金额(支付时间)", "成交概览": "退款金额(支付时间)", "自营成交": "退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	21	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
511	core	douyin_deal_daily	column	\N	transaction_refund_amount_pay_time	成交退款金额(支付时间)	douyin	\N	\N	{"合作成交": "成交退款金额(支付时间)", "成交概览": "成交退款金额(支付时间)", "自营成交": "成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	22	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
512	core	douyin_deal_daily	column	\N	refund_order_count_pay_time	退款订单数(支付时间)	douyin	\N	\N	{"合作成交": "退款订单数(支付时间)", "成交概览": "退款订单数(支付时间)", "自营成交": "退款订单数(支付时间)"}	source_header	unique_source_header	f	\N	\N	23	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
513	core	douyin_deal_daily	column	\N	product_exposure_user_count	商品曝光人数	douyin	\N	\N	{"合作成交": "商品曝光人数", "成交概览": "商品曝光人数", "自营成交": "商品曝光人数"}	source_header	unique_source_header	f	\N	\N	24	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
514	core	douyin_deal_daily	column	\N	product_click_user_count	商品点击人数	douyin	\N	\N	{"合作成交": "商品点击人数", "成交概览": "商品点击人数", "自营成交": "商品点击人数"}	source_header	unique_source_header	f	\N	\N	25	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
515	core	douyin_deal_daily	column	\N	exposure_to_click_rate_users	商品曝光-点击转化率(人数)	douyin	\N	\N	{"合作成交": "商品曝光-点击转化率(人数)", "成交概览": "商品曝光-点击转化率(人数)", "自营成交": "商品曝光-点击转化率(人数)"}	source_header	unique_source_header	f	\N	\N	26	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
516	core	douyin_deal_daily	column	\N	click_to_transaction_rate_users	商品点击-成交转化率(人数)	douyin	\N	\N	{"合作成交": "商品点击-成交转化率(人数)", "成交概览": "商品点击-成交转化率(人数)", "自营成交": "商品点击-成交转化率(人数)"}	source_header	unique_source_header	f	\N	\N	27	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
575	core	douyin_carrier_daily	column	\N	transaction_buyer_count	成交人数	douyin	\N	\N	{"载体构成": "成交人数"}	source_header	unique_source_header	f	\N	\N	27	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
517	core	douyin_deal_daily	column	\N	exposure_to_transaction_rate_users	商品曝光-成交转化率(人数)	douyin	\N	\N	{"合作成交": "商品曝光-成交转化率(人数)", "成交概览": "商品曝光-成交转化率(人数)", "自营成交": "商品曝光-成交转化率(人数)"}	source_header	unique_source_header	f	\N	\N	28	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
518	core	douyin_deal_daily	column	\N	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	douyin	\N	\N	{"合作成交": "千次曝光用户支付金额", "成交概览": "千次曝光用户支付金额", "自营成交": "千次曝光用户支付金额"}	source_header	unique_source_header	f	\N	\N	29	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
519	core	douyin_deal_daily	column	\N	product_exposure_count	商品曝光次数	douyin	\N	\N	{"合作成交": "商品曝光次数", "成交概览": "商品曝光次数", "自营成交": "商品曝光次数"}	source_header	unique_source_header	f	\N	\N	30	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
520	core	douyin_deal_daily	column	\N	product_click_count	商品点击次数	douyin	\N	\N	{"合作成交": "商品点击次数", "成交概览": "商品点击次数", "自营成交": "商品点击次数"}	source_header	unique_source_header	f	\N	\N	31	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
521	core	douyin_deal_daily	column	\N	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	douyin	\N	\N	{"合作成交": "商品曝光-点击转化率(次数)", "成交概览": "商品曝光-点击转化率(次数)", "自营成交": "商品曝光-点击转化率(次数)"}	source_header	unique_source_header	f	\N	\N	32	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
522	core	douyin_deal_daily	column	\N	click_to_transaction_rate_events	商品点击-成交转化率(次数)	douyin	\N	\N	{"合作成交": "商品点击-成交转化率(次数)", "成交概览": "商品点击-成交转化率(次数)", "自营成交": "商品点击-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	33	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
523	core	douyin_deal_daily	column	\N	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	douyin	\N	\N	{"合作成交": "商品曝光-成交转化率(次数)", "成交概览": "商品曝光-成交转化率(次数)", "自营成交": "商品曝光-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	34	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
524	core	douyin_deal_daily	column	\N	shipped_user_pay_amount_ship_time	发货用户支付金额(发货时间)	douyin	\N	\N	{"合作成交": "发货用户支付金额(发货时间)", "成交概览": "发货用户支付金额(发货时间)", "自营成交": "发货用户支付金额(发货时间)"}	source_header	unique_source_header	f	\N	\N	35	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
525	core	douyin_deal_daily	column	\N	ship_within_2_days_rate	两日内发货率	douyin	\N	\N	{"合作成交": "两日内发货率", "成交概览": "两日内发货率", "自营成交": "两日内发货率"}	source_header	unique_source_header	f	\N	\N	36	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
526	core	douyin_deal_daily	column	\N	settlement_amount	结算金额	douyin	\N	\N	{"合作成交": "结算金额", "成交概览": "结算金额", "自营成交": "结算金额"}	source_header	unique_source_header	f	\N	\N	37	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
527	core	douyin_deal_daily	column	\N	settlement_amount_refund_time	结算金额(退款时间)	douyin	\N	\N	{"合作成交": "结算金额(退款时间)", "成交概览": "结算金额(退款时间)", "自营成交": "结算金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	38	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
528	core	douyin_deal_daily	column	\N	settlement_amount_7d	7日结算金额	douyin	\N	\N	{"合作成交": "7日结算金额", "成交概览": "7日结算金额", "自营成交": "7日结算金额"}	source_header	unique_source_header	f	\N	\N	39	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
529	core	douyin_deal_daily	column	\N	settlement_amount_14d	14日结算金额	douyin	\N	\N	{"合作成交": "14日结算金额", "成交概览": "14日结算金额", "自营成交": "14日结算金额"}	source_header	unique_source_header	f	\N	\N	40	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
530	core	douyin_deal_daily	column	\N	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	douyin	\N	\N	{"合作成交": "退款后达人补贴金额(支付时间)", "成交概览": "退款后达人补贴金额(支付时间)", "自营成交": "退款后达人补贴金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	41	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
531	core	douyin_deal_daily	column	\N	creator_subsidy_amount	达人补贴金额	douyin	\N	\N	{"合作成交": "达人补贴金额", "成交概览": "达人补贴金额", "自营成交": "达人补贴金额"}	source_header	unique_source_header	f	\N	\N	42	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
532	core	douyin_deal_daily	column	\N	presale_deposit_amount	预售定金	douyin	\N	\N	{"合作成交": "预售定金", "成交概览": "预售定金", "自营成交": "预售定金"}	source_header	unique_source_header	f	\N	\N	43	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
533	core	douyin_deal_daily	column	\N	transaction_item_count	成交件数	douyin	\N	\N	{"合作成交": "成交件数", "成交概览": "成交件数", "自营成交": "成交件数"}	source_header	unique_source_header	f	\N	\N	44	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
534	core	douyin_deal_daily	column	\N	avg_item_amount	件单价	douyin	\N	\N	{"合作成交": "件单价", "成交概览": "件单价", "自营成交": "件单价"}	source_header	unique_source_header	f	\N	\N	45	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
535	core	douyin_deal_daily	column	\N	net_transaction_order_count	净成交订单量	douyin	\N	\N	{"合作成交": "净成交订单量", "成交概览": "净成交订单量", "自营成交": "净成交订单量"}	source_header	unique_source_header	f	\N	\N	46	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
536	core	douyin_deal_daily	column	\N	pre_shipment_refund_rate_pay_time	发货前退款率(支付时间)	douyin	\N	\N	{"合作成交": "发货前退款率(支付时间)", "成交概览": "发货前退款率(支付时间)", "自营成交": "发货前退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	47	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
537	core	douyin_deal_daily	column	\N	unreceived_refund_rate_pay_time	未收货退款率(支付时间)	douyin	\N	\N	{"合作成交": "未收货退款率(支付时间)", "成交概览": "未收货退款率(支付时间)", "自营成交": "未收货退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	48	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
538	core	douyin_deal_daily	column	\N	received_refund_rate_pay_time	已收货退款率(支付时间)	douyin	\N	\N	{"合作成交": "已收货退款率(支付时间)", "成交概览": "已收货退款率(支付时间)", "自营成交": "已收货退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	49	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
539	core	douyin_deal_daily	column	\N	received_return_refund_rate_pay_time	已收货退货退款率(支付时间)	douyin	\N	\N	{"合作成交": "已收货退货退款率(支付时间)", "成交概览": "已收货退货退款率(支付时间)", "自营成交": "已收货退货退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	50	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
802	core	douyin_terminal_daily	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	41	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
540	core	douyin_deal_daily	column	\N	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	douyin	\N	\N	{"合作成交": "1小时成交退款金额(支付时间)", "成交概览": "1小时成交退款金额(支付时间)", "自营成交": "1小时成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	51	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
541	core	douyin_deal_daily	column	\N	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	douyin	\N	\N	{"合作成交": "1小时退款订单数(支付时间)", "成交概览": "1小时退款订单数(支付时间)", "自营成交": "1小时退款订单数(支付时间)"}	source_header	unique_source_header	f	\N	\N	52	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
542	core	douyin_deal_daily	column	\N	one_hour_refund_rate_pay_time	1小时成交退款率(支付时间)	douyin	\N	\N	{"合作成交": "1小时成交退款率(支付时间)", "成交概览": "1小时成交退款率(支付时间)", "自营成交": "1小时成交退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	53	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
543	core	douyin_deal_daily	column	\N	net_platform_subsidy_amount_pay_time	退款后电商平台补贴金额(支付时间)	douyin	\N	\N	{"合作成交": "退款后电商平台补贴金额(支付时间)", "成交概览": "退款后电商平台补贴金额(支付时间)", "自营成交": "退款后电商平台补贴金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	54	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
544	core	douyin_deal_daily	column	\N	batch_id	导入批次ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	55	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
545	core	douyin_deal_daily	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	56	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
546	core	douyin_deal_daily	column	\N	source_row_number	源文件行号	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	57	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
490	core	douyin_deal_daily	column	\N	row_id	数据行ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
494	core	douyin_deal_daily	column	\N	carrier_type	载体类型	douyin	\N	\N	{"合作成交": "载体类型", "成交概览": "载体类型", "自营成交": "载体类型"}	source_header	unique_source_header	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
495	core	douyin_deal_daily	column	\N	ad_period	投放时段	douyin	\N	\N	{"合作成交": "投放时段", "成交概览": "投放时段", "自营成交": "投放时段"}	source_header	unique_source_header	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
547	core	douyin_deal_daily	column	\N	imported_at	写入时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	58	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
550	core	douyin_carrier_daily	column	\N	shop_id	店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
551	core	douyin_carrier_daily	column	\N	biz_date	日期	douyin	\N	\N	{"载体构成": "日期"}	source_header	unique_source_header	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
556	core	douyin_carrier_daily	column	\N	transaction_amount	成交金额	douyin	\N	\N	{"载体构成": "成交金额"}	source_header	unique_source_header	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
557	core	douyin_carrier_daily	column	\N	user_pay_amount	用户支付金额	douyin	\N	\N	{"载体构成": "用户支付金额"}	source_header	unique_source_header	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
558	core	douyin_carrier_daily	column	\N	settlement_amount	结算金额	douyin	\N	\N	{"载体构成": "结算金额"}	source_header	unique_source_header	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
559	core	douyin_carrier_daily	column	\N	transaction_refund_amount_pay_time	成交退款金额(支付时间)	douyin	\N	\N	{"载体构成": "成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
560	core	douyin_carrier_daily	column	\N	refund_amount_pay_time	退款金额(支付时间)	douyin	\N	\N	{"载体构成": "退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
561	core	douyin_carrier_daily	column	\N	refund_rate_pay_time	退款率(支付时间)	douyin	\N	\N	{"载体构成": "退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
562	core	douyin_carrier_daily	column	\N	ad_attributed_transaction_amount	投放贡献成交金额	douyin	\N	\N	{"载体构成": "投放贡献成交金额"}	source_header	unique_source_header	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
563	core	douyin_carrier_daily	column	\N	ad_attributed_transaction_share	投放贡献成交占比	douyin	\N	\N	{"载体构成": "投放贡献成交占比"}	source_header	unique_source_header	f	\N	\N	15	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
564	core	douyin_carrier_daily	column	\N	ad_spend_shop_promoted	投放消耗(店铺被投)	douyin	\N	\N	{"载体构成": "投放消耗(店铺被投)"}	source_header	unique_source_header	f	\N	\N	16	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
565	core	douyin_carrier_daily	column	\N	ad_spend_rate_net_refund_shop_promoted	投放费比(剔除退款、店铺被投)	douyin	\N	\N	{"载体构成": "投放费比(剔除退款、店铺被投)"}	source_header	unique_source_header	f	\N	\N	17	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
566	core	douyin_carrier_daily	column	\N	exposure_to_click_rate_users	商品曝光-点击转化率(人数)	douyin	\N	\N	{"载体构成": "商品曝光-点击转化率(人数)"}	source_header	unique_source_header	f	\N	\N	18	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
567	core	douyin_carrier_daily	column	\N	click_to_transaction_rate_users	商品点击-成交转化率(人数)	douyin	\N	\N	{"载体构成": "商品点击-成交转化率(人数)"}	source_header	unique_source_header	f	\N	\N	19	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
568	core	douyin_carrier_daily	column	\N	smart_coupon_amount	智能优惠券金额	douyin	\N	\N	{"载体构成": "智能优惠券金额"}	source_header	unique_source_header	f	\N	\N	20	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
569	core	douyin_carrier_daily	column	\N	platform_subsidy_amount	平台补贴金额	douyin	\N	\N	{"载体构成": "平台补贴金额"}	source_header	unique_source_header	f	\N	\N	21	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
570	core	douyin_carrier_daily	column	\N	creator_subsidy_amount	达人补贴金额	douyin	\N	\N	{"载体构成": "达人补贴金额"}	source_header	unique_source_header	f	\N	\N	22	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
571	core	douyin_carrier_daily	column	\N	presale_deposit_amount	预售定金	douyin	\N	\N	{"载体构成": "预售定金"}	source_header	unique_source_header	f	\N	\N	23	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
572	core	douyin_carrier_daily	column	\N	transaction_order_count	成交订单数	douyin	\N	\N	{"载体构成": "成交订单数"}	source_header	unique_source_header	f	\N	\N	24	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
573	core	douyin_carrier_daily	column	\N	transaction_item_count	成交件数	douyin	\N	\N	{"载体构成": "成交件数"}	source_header	unique_source_header	f	\N	\N	25	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
574	core	douyin_carrier_daily	column	\N	avg_item_amount	件单价	douyin	\N	\N	{"载体构成": "件单价"}	source_header	unique_source_header	f	\N	\N	26	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
576	core	douyin_carrier_daily	column	\N	avg_customer_amount	客单价	douyin	\N	\N	{"载体构成": "客单价"}	source_header	unique_source_header	f	\N	\N	28	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
577	core	douyin_carrier_daily	column	\N	net_transaction_amount	净成交金额	douyin	\N	\N	{"载体构成": "净成交金额"}	source_header	unique_source_header	f	\N	\N	29	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
578	core	douyin_carrier_daily	column	\N	net_transaction_order_count	净成交订单量	douyin	\N	\N	{"载体构成": "净成交订单量"}	source_header	unique_source_header	f	\N	\N	30	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
579	core	douyin_carrier_daily	column	\N	settlement_amount_7d	7日结算金额	douyin	\N	\N	{"载体构成": "7日结算金额"}	source_header	unique_source_header	f	\N	\N	31	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
580	core	douyin_carrier_daily	column	\N	settlement_amount_14d	14日结算金额	douyin	\N	\N	{"载体构成": "14日结算金额"}	source_header	unique_source_header	f	\N	\N	32	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
581	core	douyin_carrier_daily	column	\N	settlement_amount_refund_time	结算金额(退款时间)	douyin	\N	\N	{"载体构成": "结算金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	33	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
582	core	douyin_carrier_daily	column	\N	ad_attributed_settlement_amount	投放贡献结算金额	douyin	\N	\N	{"载体构成": "投放贡献结算金额"}	source_header	unique_source_header	f	\N	\N	34	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
583	core	douyin_carrier_daily	column	\N	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	douyin	\N	\N	{"载体构成": "退款后用户支付金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	35	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
584	core	douyin_carrier_daily	column	\N	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	douyin	\N	\N	{"载体构成": "退款后智能优惠券金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	36	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
585	core	douyin_carrier_daily	column	\N	net_platform_subsidy_amount_pay_time	退款后平台补贴金额(支付时间)	douyin	\N	\N	{"载体构成": "退款后平台补贴金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	37	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
586	core	douyin_carrier_daily	column	\N	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	douyin	\N	\N	{"载体构成": "退款后达人补贴金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	38	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
587	core	douyin_carrier_daily	column	\N	refund_order_count_pay_time	退款订单数(支付时间)	douyin	\N	\N	{"载体构成": "退款订单数(支付时间)"}	source_header	unique_source_header	f	\N	\N	39	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
588	core	douyin_carrier_daily	column	\N	transaction_refund_amount_refund_time	成交退款金额(退款时间)	douyin	\N	\N	{"载体构成": "成交退款金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	40	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
589	core	douyin_carrier_daily	column	\N	refund_amount_refund_time	退款金额(退款时间)	douyin	\N	\N	{"载体构成": "退款金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	41	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
590	core	douyin_carrier_daily	column	\N	refund_order_count_refund_time	退款订单数(退款时间)	douyin	\N	\N	{"载体构成": "退款订单数(退款时间)"}	source_header	unique_source_header	f	\N	\N	42	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
591	core	douyin_carrier_daily	column	\N	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	douyin	\N	\N	{"载体构成": "1小时成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	43	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
592	core	douyin_carrier_daily	column	\N	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	douyin	\N	\N	{"载体构成": "1小时退款订单数(支付时间)"}	source_header	unique_source_header	f	\N	\N	44	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
593	core	douyin_carrier_daily	column	\N	one_hour_refund_rate_pay_time	1小时退款率(支付时间)	douyin	\N	\N	{"载体构成": "1小时退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	45	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
594	core	douyin_carrier_daily	column	\N	ad_attributed_transaction_refund_amount_pay_time	投放贡献成交退款金额(支付时间)	douyin	\N	\N	{"载体构成": "投放贡献成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	46	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
595	core	douyin_carrier_daily	column	\N	ad_attributed_refund_rate_pay_time	投放部分退款率(支付时间)	douyin	\N	\N	{"载体构成": "投放部分退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	47	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
596	core	douyin_carrier_daily	column	\N	product_exposure_count	商品曝光次数	douyin	\N	\N	{"载体构成": "商品曝光次数"}	source_header	unique_source_header	f	\N	\N	48	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
597	core	douyin_carrier_daily	column	\N	product_click_count	商品点击次数	douyin	\N	\N	{"载体构成": "商品点击次数"}	source_header	unique_source_header	f	\N	\N	49	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
598	core	douyin_carrier_daily	column	\N	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	douyin	\N	\N	{"载体构成": "商品曝光-点击转化率(次数)"}	source_header	unique_source_header	f	\N	\N	50	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
599	core	douyin_carrier_daily	column	\N	click_to_transaction_rate_events	商品点击-成交转化率(次数)	douyin	\N	\N	{"载体构成": "商品点击-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	51	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
600	core	douyin_carrier_daily	column	\N	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	douyin	\N	\N	{"载体构成": "商品曝光-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	52	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
601	core	douyin_carrier_daily	column	\N	product_exposure_user_count	商品曝光人数	douyin	\N	\N	{"载体构成": "商品曝光人数"}	source_header	unique_source_header	f	\N	\N	53	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
602	core	douyin_carrier_daily	column	\N	product_click_user_count	商品点击人数	douyin	\N	\N	{"载体构成": "商品点击人数"}	source_header	unique_source_header	f	\N	\N	54	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
603	core	douyin_carrier_daily	column	\N	exposure_to_transaction_rate_users	商品曝光-成交转化率(人数)	douyin	\N	\N	{"载体构成": "商品曝光-成交转化率(人数)"}	source_header	unique_source_header	f	\N	\N	55	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
604	core	douyin_carrier_daily	column	\N	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	douyin	\N	\N	{"载体构成": "千次曝光用户支付金额"}	source_header	unique_source_header	f	\N	\N	56	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
605	core	douyin_carrier_daily	column	\N	ad_spend_shop_bound	投放消耗(店铺绑定)	douyin	\N	\N	{"载体构成": "投放消耗(店铺绑定)"}	source_header	unique_source_header	f	\N	\N	57	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
803	core	douyin_terminal_daily	column	\N	source_row_number	源文件行号	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	42	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
606	core	douyin_carrier_daily	column	\N	platform_commission_settlement	平台佣金(结算口径)	douyin	\N	\N	{"载体构成": "平台佣金(结算口径)"}	source_header	unique_source_header	f	\N	\N	58	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
607	core	douyin_carrier_daily	column	\N	creator_commission_settlement	达人佣金(结算口径)	douyin	\N	\N	{"载体构成": "达人佣金(结算口径)"}	source_header	unique_source_header	f	\N	\N	59	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
608	core	douyin_carrier_daily	column	\N	ad_spend_rate_shop_bound	投放费比(店铺绑定)	douyin	\N	\N	{"载体构成": "投放费比(店铺绑定)"}	source_header	unique_source_header	f	\N	\N	60	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
609	core	douyin_carrier_daily	column	\N	ad_spend_rate_shop_promoted	投放费比(店铺被投)	douyin	\N	\N	{"载体构成": "投放费比(店铺被投)"}	source_header	unique_source_header	f	\N	\N	61	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
610	core	douyin_carrier_daily	column	\N	ad_spend_rate_net_refund_shop_bound	投放费比(剔除退款、店铺绑定)	douyin	\N	\N	{"载体构成": "投放费比(剔除退款、店铺绑定)"}	source_header	unique_source_header	f	\N	\N	62	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
611	core	douyin_carrier_daily	column	\N	total_expense_rate_shop_bound	综合费比(店铺绑定)	douyin	\N	\N	{"载体构成": "综合费比(店铺绑定)"}	source_header	unique_source_header	f	\N	\N	63	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
612	core	douyin_carrier_daily	column	\N	total_expense_rate_shop_promoted	综合费比(店铺被投)	douyin	\N	\N	{"载体构成": "综合费比(店铺被投)"}	source_header	unique_source_header	f	\N	\N	64	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
613	core	douyin_carrier_daily	column	\N	total_expense_rate_net_refund_shop_bound	综合费比(剔除退款、店铺绑定)	douyin	\N	\N	{"载体构成": "综合费比(剔除退款、店铺绑定)"}	source_header	unique_source_header	f	\N	\N	65	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
614	core	douyin_carrier_daily	column	\N	total_expense_rate_net_refund_shop_promoted	综合费比(剔除退款、店铺被投)	douyin	\N	\N	{"载体构成": "综合费比(剔除退款、店铺被投)"}	source_header	unique_source_header	f	\N	\N	66	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
615	core	douyin_carrier_daily	column	\N	batch_id	导入批次ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	67	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
616	core	douyin_carrier_daily	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	68	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
617	core	douyin_carrier_daily	column	\N	source_row_number	源文件行号	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	69	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
549	core	douyin_carrier_daily	column	\N	row_id	数据行ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
552	core	douyin_carrier_daily	column	\N	sale_scope	自营/合作	douyin	\N	\N	{"载体构成": "自营/合作"}	source_header	unique_source_header	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
553	core	douyin_carrier_daily	column	\N	carrier_type	载体类型	douyin	\N	\N	{"载体构成": "载体类型"}	source_header	unique_source_header	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
554	core	douyin_carrier_daily	column	\N	account_channel	账号/渠道	douyin	\N	\N	{"载体构成": "账号/渠道"}	source_header	unique_source_header	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
555	core	douyin_carrier_daily	column	\N	douyin_account_id	抖音号	douyin	\N	\N	{"载体构成": "抖音号"}	source_header	unique_source_header	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
618	core	douyin_carrier_daily	column	\N	imported_at	写入时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	70	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
621	core	douyin_account_daily	column	\N	shop_id	店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
622	core	douyin_account_daily	column	\N	biz_date	日期	douyin	\N	\N	{"账号构成": "日期"}	source_header	unique_source_header	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
627	core	douyin_account_daily	column	\N	transaction_amount	成交金额	douyin	\N	\N	{"账号构成": "成交金额"}	source_header	unique_source_header	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
628	core	douyin_account_daily	column	\N	user_pay_amount	用户支付金额	douyin	\N	\N	{"账号构成": "用户支付金额"}	source_header	unique_source_header	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
629	core	douyin_account_daily	column	\N	settlement_amount	结算金额	douyin	\N	\N	{"账号构成": "结算金额"}	source_header	unique_source_header	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
630	core	douyin_account_daily	column	\N	transaction_refund_amount_pay_time	成交退款金额(支付时间)	douyin	\N	\N	{"账号构成": "成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
631	core	douyin_account_daily	column	\N	refund_amount_pay_time	退款金额(支付时间)	douyin	\N	\N	{"账号构成": "退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
632	core	douyin_account_daily	column	\N	refund_rate_pay_time	退款率(支付时间)	douyin	\N	\N	{"账号构成": "退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
633	core	douyin_account_daily	column	\N	ad_attributed_transaction_amount	投放贡献成交金额	douyin	\N	\N	{"账号构成": "投放贡献成交金额"}	source_header	unique_source_header	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
634	core	douyin_account_daily	column	\N	ad_attributed_transaction_share	投放贡献成交占比	douyin	\N	\N	{"账号构成": "投放贡献成交占比"}	source_header	unique_source_header	f	\N	\N	15	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
635	core	douyin_account_daily	column	\N	ad_spend_shop_promoted	投放消耗(店铺被投)	douyin	\N	\N	{"账号构成": "投放消耗(店铺被投)"}	source_header	unique_source_header	f	\N	\N	16	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
636	core	douyin_account_daily	column	\N	ad_spend_rate_net_refund_shop_promoted	投放费比(剔除退款、店铺被投)	douyin	\N	\N	{"账号构成": "投放费比(剔除退款、店铺被投)"}	source_header	unique_source_header	f	\N	\N	17	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
637	core	douyin_account_daily	column	\N	exposure_to_click_rate_users	商品曝光-点击转化率(人数)	douyin	\N	\N	{"账号构成": "商品曝光-点击转化率(人数)"}	source_header	unique_source_header	f	\N	\N	18	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
638	core	douyin_account_daily	column	\N	click_to_transaction_rate_users	商品点击-成交转化率(人数)	douyin	\N	\N	{"账号构成": "商品点击-成交转化率(人数)"}	source_header	unique_source_header	f	\N	\N	19	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
639	core	douyin_account_daily	column	\N	smart_coupon_amount	智能优惠券金额	douyin	\N	\N	{"账号构成": "智能优惠券金额"}	source_header	unique_source_header	f	\N	\N	20	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
640	core	douyin_account_daily	column	\N	platform_subsidy_amount	平台补贴金额	douyin	\N	\N	{"账号构成": "平台补贴金额"}	source_header	unique_source_header	f	\N	\N	21	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
641	core	douyin_account_daily	column	\N	creator_subsidy_amount	达人补贴金额	douyin	\N	\N	{"账号构成": "达人补贴金额"}	source_header	unique_source_header	f	\N	\N	22	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
642	core	douyin_account_daily	column	\N	presale_deposit_amount	预售定金	douyin	\N	\N	{"账号构成": "预售定金"}	source_header	unique_source_header	f	\N	\N	23	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
643	core	douyin_account_daily	column	\N	transaction_order_count	成交订单数	douyin	\N	\N	{"账号构成": "成交订单数"}	source_header	unique_source_header	f	\N	\N	24	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
644	core	douyin_account_daily	column	\N	transaction_item_count	成交件数	douyin	\N	\N	{"账号构成": "成交件数"}	source_header	unique_source_header	f	\N	\N	25	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
645	core	douyin_account_daily	column	\N	avg_item_amount	件单价	douyin	\N	\N	{"账号构成": "件单价"}	source_header	unique_source_header	f	\N	\N	26	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
646	core	douyin_account_daily	column	\N	transaction_buyer_count	成交人数	douyin	\N	\N	{"账号构成": "成交人数"}	source_header	unique_source_header	f	\N	\N	27	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
647	core	douyin_account_daily	column	\N	avg_customer_amount	客单价	douyin	\N	\N	{"账号构成": "客单价"}	source_header	unique_source_header	f	\N	\N	28	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
648	core	douyin_account_daily	column	\N	net_transaction_amount	净成交金额	douyin	\N	\N	{"账号构成": "净成交金额"}	source_header	unique_source_header	f	\N	\N	29	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
649	core	douyin_account_daily	column	\N	net_transaction_order_count	净成交订单量	douyin	\N	\N	{"账号构成": "净成交订单量"}	source_header	unique_source_header	f	\N	\N	30	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
650	core	douyin_account_daily	column	\N	settlement_amount_7d	7日结算金额	douyin	\N	\N	{"账号构成": "7日结算金额"}	source_header	unique_source_header	f	\N	\N	31	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
651	core	douyin_account_daily	column	\N	settlement_amount_14d	14日结算金额	douyin	\N	\N	{"账号构成": "14日结算金额"}	source_header	unique_source_header	f	\N	\N	32	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
652	core	douyin_account_daily	column	\N	settlement_amount_refund_time	结算金额(退款时间)	douyin	\N	\N	{"账号构成": "结算金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	33	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
653	core	douyin_account_daily	column	\N	ad_attributed_settlement_amount	投放贡献结算金额	douyin	\N	\N	{"账号构成": "投放贡献结算金额"}	source_header	unique_source_header	f	\N	\N	34	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
654	core	douyin_account_daily	column	\N	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	douyin	\N	\N	{"账号构成": "退款后用户支付金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	35	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
655	core	douyin_account_daily	column	\N	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	douyin	\N	\N	{"账号构成": "退款后智能优惠券金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	36	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
656	core	douyin_account_daily	column	\N	net_platform_subsidy_amount_pay_time	退款后平台补贴金额(支付时间)	douyin	\N	\N	{"账号构成": "退款后平台补贴金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	37	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
657	core	douyin_account_daily	column	\N	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	douyin	\N	\N	{"账号构成": "退款后达人补贴金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	38	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
658	core	douyin_account_daily	column	\N	refund_order_count_pay_time	退款订单数(支付时间)	douyin	\N	\N	{"账号构成": "退款订单数(支付时间)"}	source_header	unique_source_header	f	\N	\N	39	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
659	core	douyin_account_daily	column	\N	transaction_refund_amount_refund_time	成交退款金额(退款时间)	douyin	\N	\N	{"账号构成": "成交退款金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	40	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
660	core	douyin_account_daily	column	\N	refund_amount_refund_time	退款金额(退款时间)	douyin	\N	\N	{"账号构成": "退款金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	41	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
661	core	douyin_account_daily	column	\N	refund_order_count_refund_time	退款订单数(退款时间)	douyin	\N	\N	{"账号构成": "退款订单数(退款时间)"}	source_header	unique_source_header	f	\N	\N	42	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
662	core	douyin_account_daily	column	\N	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	douyin	\N	\N	{"账号构成": "1小时成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	43	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
663	core	douyin_account_daily	column	\N	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	douyin	\N	\N	{"账号构成": "1小时退款订单数(支付时间)"}	source_header	unique_source_header	f	\N	\N	44	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
664	core	douyin_account_daily	column	\N	one_hour_refund_rate_pay_time	1小时退款率(支付时间)	douyin	\N	\N	{"账号构成": "1小时退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	45	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
665	core	douyin_account_daily	column	\N	ad_attributed_transaction_refund_amount_pay_time	投放贡献成交退款金额(支付时间)	douyin	\N	\N	{"账号构成": "投放贡献成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	46	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
666	core	douyin_account_daily	column	\N	ad_attributed_refund_rate_pay_time	投放部分退款率(支付时间)	douyin	\N	\N	{"账号构成": "投放部分退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	47	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
667	core	douyin_account_daily	column	\N	product_exposure_count	商品曝光次数	douyin	\N	\N	{"账号构成": "商品曝光次数"}	source_header	unique_source_header	f	\N	\N	48	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
668	core	douyin_account_daily	column	\N	product_click_count	商品点击次数	douyin	\N	\N	{"账号构成": "商品点击次数"}	source_header	unique_source_header	f	\N	\N	49	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
669	core	douyin_account_daily	column	\N	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	douyin	\N	\N	{"账号构成": "商品曝光-点击转化率(次数)"}	source_header	unique_source_header	f	\N	\N	50	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
670	core	douyin_account_daily	column	\N	click_to_transaction_rate_events	商品点击-成交转化率(次数)	douyin	\N	\N	{"账号构成": "商品点击-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	51	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
671	core	douyin_account_daily	column	\N	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	douyin	\N	\N	{"账号构成": "商品曝光-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	52	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
672	core	douyin_account_daily	column	\N	product_exposure_user_count	商品曝光人数	douyin	\N	\N	{"账号构成": "商品曝光人数"}	source_header	unique_source_header	f	\N	\N	53	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
673	core	douyin_account_daily	column	\N	product_click_user_count	商品点击人数	douyin	\N	\N	{"账号构成": "商品点击人数"}	source_header	unique_source_header	f	\N	\N	54	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
674	core	douyin_account_daily	column	\N	exposure_to_transaction_rate_users	商品曝光-成交转化率(人数)	douyin	\N	\N	{"账号构成": "商品曝光-成交转化率(人数)"}	source_header	unique_source_header	f	\N	\N	55	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
675	core	douyin_account_daily	column	\N	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	douyin	\N	\N	{"账号构成": "千次曝光用户支付金额"}	source_header	unique_source_header	f	\N	\N	56	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
676	core	douyin_account_daily	column	\N	ad_spend_shop_bound	投放消耗(店铺绑定)	douyin	\N	\N	{"账号构成": "投放消耗(店铺绑定)"}	source_header	unique_source_header	f	\N	\N	57	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
677	core	douyin_account_daily	column	\N	platform_commission_settlement	平台佣金(结算口径)	douyin	\N	\N	{"账号构成": "平台佣金(结算口径)"}	source_header	unique_source_header	f	\N	\N	58	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
678	core	douyin_account_daily	column	\N	creator_commission_settlement	达人佣金(结算口径)	douyin	\N	\N	{"账号构成": "达人佣金(结算口径)"}	source_header	unique_source_header	f	\N	\N	59	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
679	core	douyin_account_daily	column	\N	ad_spend_rate_shop_bound	投放费比(店铺绑定)	douyin	\N	\N	{"账号构成": "投放费比(店铺绑定)"}	source_header	unique_source_header	f	\N	\N	60	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
680	core	douyin_account_daily	column	\N	ad_spend_rate_shop_promoted	投放费比(店铺被投)	douyin	\N	\N	{"账号构成": "投放费比(店铺被投)"}	source_header	unique_source_header	f	\N	\N	61	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
681	core	douyin_account_daily	column	\N	ad_spend_rate_net_refund_shop_bound	投放费比(剔除退款、店铺绑定)	douyin	\N	\N	{"账号构成": "投放费比(剔除退款、店铺绑定)"}	source_header	unique_source_header	f	\N	\N	62	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
682	core	douyin_account_daily	column	\N	total_expense_rate_shop_bound	综合费比(店铺绑定)	douyin	\N	\N	{"账号构成": "综合费比(店铺绑定)"}	source_header	unique_source_header	f	\N	\N	63	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
683	core	douyin_account_daily	column	\N	total_expense_rate_shop_promoted	综合费比(店铺被投)	douyin	\N	\N	{"账号构成": "综合费比(店铺被投)"}	source_header	unique_source_header	f	\N	\N	64	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
684	core	douyin_account_daily	column	\N	total_expense_rate_net_refund_shop_bound	综合费比(剔除退款、店铺绑定)	douyin	\N	\N	{"账号构成": "综合费比(剔除退款、店铺绑定)"}	source_header	unique_source_header	f	\N	\N	65	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
685	core	douyin_account_daily	column	\N	total_expense_rate_net_refund_shop_promoted	综合费比(剔除退款、店铺被投)	douyin	\N	\N	{"账号构成": "综合费比(剔除退款、店铺被投)"}	source_header	unique_source_header	f	\N	\N	66	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
686	core	douyin_account_daily	column	\N	batch_id	导入批次ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	67	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
687	core	douyin_account_daily	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	68	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
688	core	douyin_account_daily	column	\N	source_row_number	源文件行号	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	69	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
620	core	douyin_account_daily	column	\N	row_id	数据行ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
623	core	douyin_account_daily	column	\N	account_name	账号名称	douyin	\N	\N	{"账号构成": "账号名称"}	source_header	unique_source_header	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
624	core	douyin_account_daily	column	\N	account_type	账号类型	douyin	\N	\N	{"账号构成": "账号类型"}	source_header	unique_source_header	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
625	core	douyin_account_daily	column	\N	sale_scope	自营/合作	douyin	\N	\N	{"账号构成": "自营/合作"}	source_header	unique_source_header	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
626	core	douyin_account_daily	column	\N	douyin_account_id	抖音号	douyin	\N	\N	{"账号构成": "抖音号"}	source_header	unique_source_header	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
689	core	douyin_account_daily	column	\N	imported_at	写入时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	70	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
692	core	douyin_content_daily	column	\N	shop_id	店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
693	core	douyin_content_daily	column	\N	biz_date	日期	douyin	\N	\N	{"单载体构成": "日期"}	source_header	unique_source_header	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
697	core	douyin_content_daily	column	\N	content_title	标题/名称	douyin	\N	\N	{"单载体构成": "标题/名称"}	source_header	unique_source_header	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
698	core	douyin_content_daily	column	\N	transaction_amount	成交金额	douyin	\N	\N	{"单载体构成": "成交金额"}	source_header	unique_source_header	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
699	core	douyin_content_daily	column	\N	user_pay_amount	用户支付金额	douyin	\N	\N	{"单载体构成": "用户支付金额"}	source_header	unique_source_header	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
700	core	douyin_content_daily	column	\N	settlement_amount	结算金额	douyin	\N	\N	{"单载体构成": "结算金额"}	source_header	unique_source_header	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
701	core	douyin_content_daily	column	\N	transaction_refund_amount_pay_time	成交退款金额(支付时间)	douyin	\N	\N	{"单载体构成": "成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
702	core	douyin_content_daily	column	\N	refund_amount_pay_time	退款金额(支付时间)	douyin	\N	\N	{"单载体构成": "退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
703	core	douyin_content_daily	column	\N	refund_rate_pay_time	退款率(支付时间)	douyin	\N	\N	{"单载体构成": "退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
704	core	douyin_content_daily	column	\N	ad_attributed_transaction_amount	投放贡献成交金额	douyin	\N	\N	{"单载体构成": "投放贡献成交金额"}	source_header	unique_source_header	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
705	core	douyin_content_daily	column	\N	ad_attributed_transaction_share	投放贡献成交占比	douyin	\N	\N	{"单载体构成": "投放贡献成交占比"}	source_header	unique_source_header	f	\N	\N	15	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
706	core	douyin_content_daily	column	\N	ad_spend_shop_promoted	投放消耗(店铺被投)	douyin	\N	\N	{"单载体构成": "投放消耗(店铺被投)"}	source_header	unique_source_header	f	\N	\N	16	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
707	core	douyin_content_daily	column	\N	ad_spend_rate_net_refund_shop_promoted	投放费比(剔除退款、店铺被投)	douyin	\N	\N	{"单载体构成": "投放费比(剔除退款、店铺被投)"}	source_header	unique_source_header	f	\N	\N	17	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
708	core	douyin_content_daily	column	\N	exposure_to_click_rate_users	商品曝光-点击转化率(人数)	douyin	\N	\N	{"单载体构成": "商品曝光-点击转化率(人数)"}	source_header	unique_source_header	f	\N	\N	18	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
709	core	douyin_content_daily	column	\N	click_to_transaction_rate_users	商品点击-成交转化率(人数)	douyin	\N	\N	{"单载体构成": "商品点击-成交转化率(人数)"}	source_header	unique_source_header	f	\N	\N	19	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
710	core	douyin_content_daily	column	\N	smart_coupon_amount	智能优惠券金额	douyin	\N	\N	{"单载体构成": "智能优惠券金额"}	source_header	unique_source_header	f	\N	\N	20	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
711	core	douyin_content_daily	column	\N	platform_subsidy_amount	平台补贴金额	douyin	\N	\N	{"单载体构成": "平台补贴金额"}	source_header	unique_source_header	f	\N	\N	21	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
712	core	douyin_content_daily	column	\N	creator_subsidy_amount	达人补贴金额	douyin	\N	\N	{"单载体构成": "达人补贴金额"}	source_header	unique_source_header	f	\N	\N	22	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
713	core	douyin_content_daily	column	\N	presale_deposit_amount	预售定金	douyin	\N	\N	{"单载体构成": "预售定金"}	source_header	unique_source_header	f	\N	\N	23	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
714	core	douyin_content_daily	column	\N	transaction_order_count	成交订单数	douyin	\N	\N	{"单载体构成": "成交订单数"}	source_header	unique_source_header	f	\N	\N	24	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
715	core	douyin_content_daily	column	\N	transaction_item_count	成交件数	douyin	\N	\N	{"单载体构成": "成交件数"}	source_header	unique_source_header	f	\N	\N	25	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
716	core	douyin_content_daily	column	\N	avg_item_amount	件单价	douyin	\N	\N	{"单载体构成": "件单价"}	source_header	unique_source_header	f	\N	\N	26	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
717	core	douyin_content_daily	column	\N	transaction_buyer_count	成交人数	douyin	\N	\N	{"单载体构成": "成交人数"}	source_header	unique_source_header	f	\N	\N	27	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
718	core	douyin_content_daily	column	\N	avg_customer_amount	客单价	douyin	\N	\N	{"单载体构成": "客单价"}	source_header	unique_source_header	f	\N	\N	28	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
719	core	douyin_content_daily	column	\N	net_transaction_amount	净成交金额	douyin	\N	\N	{"单载体构成": "净成交金额"}	source_header	unique_source_header	f	\N	\N	29	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
720	core	douyin_content_daily	column	\N	net_transaction_order_count	净成交订单量	douyin	\N	\N	{"单载体构成": "净成交订单量"}	source_header	unique_source_header	f	\N	\N	30	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
721	core	douyin_content_daily	column	\N	settlement_amount_7d	7日结算金额	douyin	\N	\N	{"单载体构成": "7日结算金额"}	source_header	unique_source_header	f	\N	\N	31	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
722	core	douyin_content_daily	column	\N	settlement_amount_14d	14日结算金额	douyin	\N	\N	{"单载体构成": "14日结算金额"}	source_header	unique_source_header	f	\N	\N	32	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
723	core	douyin_content_daily	column	\N	settlement_amount_refund_time	结算金额(退款时间)	douyin	\N	\N	{"单载体构成": "结算金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	33	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
724	core	douyin_content_daily	column	\N	ad_attributed_settlement_amount	投放贡献结算金额	douyin	\N	\N	{"单载体构成": "投放贡献结算金额"}	source_header	unique_source_header	f	\N	\N	34	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
725	core	douyin_content_daily	column	\N	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	douyin	\N	\N	{"单载体构成": "退款后用户支付金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	35	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
726	core	douyin_content_daily	column	\N	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	douyin	\N	\N	{"单载体构成": "退款后智能优惠券金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	36	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
727	core	douyin_content_daily	column	\N	net_platform_subsidy_amount_pay_time	退款后平台补贴金额(支付时间)	douyin	\N	\N	{"单载体构成": "退款后平台补贴金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	37	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
728	core	douyin_content_daily	column	\N	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	douyin	\N	\N	{"单载体构成": "退款后达人补贴金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	38	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
729	core	douyin_content_daily	column	\N	refund_order_count_pay_time	退款订单数(支付时间)	douyin	\N	\N	{"单载体构成": "退款订单数(支付时间)"}	source_header	unique_source_header	f	\N	\N	39	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
730	core	douyin_content_daily	column	\N	transaction_refund_amount_refund_time	成交退款金额(退款时间)	douyin	\N	\N	{"单载体构成": "成交退款金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	40	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
731	core	douyin_content_daily	column	\N	refund_amount_refund_time	退款金额(退款时间)	douyin	\N	\N	{"单载体构成": "退款金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	41	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
732	core	douyin_content_daily	column	\N	refund_order_count_refund_time	退款订单数(退款时间)	douyin	\N	\N	{"单载体构成": "退款订单数(退款时间)"}	source_header	unique_source_header	f	\N	\N	42	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
733	core	douyin_content_daily	column	\N	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	douyin	\N	\N	{"单载体构成": "1小时成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	43	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
734	core	douyin_content_daily	column	\N	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	douyin	\N	\N	{"单载体构成": "1小时退款订单数(支付时间)"}	source_header	unique_source_header	f	\N	\N	44	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
735	core	douyin_content_daily	column	\N	one_hour_refund_rate_pay_time	1小时退款率(支付时间)	douyin	\N	\N	{"单载体构成": "1小时退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	45	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
736	core	douyin_content_daily	column	\N	ad_attributed_transaction_refund_amount_pay_time	投放贡献成交退款金额(支付时间)	douyin	\N	\N	{"单载体构成": "投放贡献成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	46	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
737	core	douyin_content_daily	column	\N	ad_attributed_refund_rate_pay_time	投放部分退款率(支付时间)	douyin	\N	\N	{"单载体构成": "投放部分退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	47	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
738	core	douyin_content_daily	column	\N	product_exposure_count	商品曝光次数	douyin	\N	\N	{"单载体构成": "商品曝光次数"}	source_header	unique_source_header	f	\N	\N	48	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
739	core	douyin_content_daily	column	\N	product_click_count	商品点击次数	douyin	\N	\N	{"单载体构成": "商品点击次数"}	source_header	unique_source_header	f	\N	\N	49	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
740	core	douyin_content_daily	column	\N	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	douyin	\N	\N	{"单载体构成": "商品曝光-点击转化率(次数)"}	source_header	unique_source_header	f	\N	\N	50	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
741	core	douyin_content_daily	column	\N	click_to_transaction_rate_events	商品点击-成交转化率(次数)	douyin	\N	\N	{"单载体构成": "商品点击-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	51	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
742	core	douyin_content_daily	column	\N	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	douyin	\N	\N	{"单载体构成": "商品曝光-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	52	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
743	core	douyin_content_daily	column	\N	product_exposure_user_count	商品曝光人数	douyin	\N	\N	{"单载体构成": "商品曝光人数"}	source_header	unique_source_header	f	\N	\N	53	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
744	core	douyin_content_daily	column	\N	product_click_user_count	商品点击人数	douyin	\N	\N	{"单载体构成": "商品点击人数"}	source_header	unique_source_header	f	\N	\N	54	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
745	core	douyin_content_daily	column	\N	exposure_to_transaction_rate_users	商品曝光-成交转化率(人数)	douyin	\N	\N	{"单载体构成": "商品曝光-成交转化率(人数)"}	source_header	unique_source_header	f	\N	\N	55	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
746	core	douyin_content_daily	column	\N	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	douyin	\N	\N	{"单载体构成": "千次曝光用户支付金额"}	source_header	unique_source_header	f	\N	\N	56	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
747	core	douyin_content_daily	column	\N	ad_spend_shop_bound	投放消耗(店铺绑定)	douyin	\N	\N	{"单载体构成": "投放消耗(店铺绑定)"}	source_header	unique_source_header	f	\N	\N	57	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
748	core	douyin_content_daily	column	\N	platform_commission_settlement	平台佣金(结算口径)	douyin	\N	\N	{"单载体构成": "平台佣金(结算口径)"}	source_header	unique_source_header	f	\N	\N	58	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
749	core	douyin_content_daily	column	\N	creator_commission_settlement	达人佣金(结算口径)	douyin	\N	\N	{"单载体构成": "达人佣金(结算口径)"}	source_header	unique_source_header	f	\N	\N	59	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
750	core	douyin_content_daily	column	\N	ad_spend_rate_shop_bound	投放费比(店铺绑定)	douyin	\N	\N	{"单载体构成": "投放费比(店铺绑定)"}	source_header	unique_source_header	f	\N	\N	60	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
751	core	douyin_content_daily	column	\N	ad_spend_rate_shop_promoted	投放费比(店铺被投)	douyin	\N	\N	{"单载体构成": "投放费比(店铺被投)"}	source_header	unique_source_header	f	\N	\N	61	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
752	core	douyin_content_daily	column	\N	ad_spend_rate_net_refund_shop_bound	投放费比(剔除退款、店铺绑定)	douyin	\N	\N	{"单载体构成": "投放费比(剔除退款、店铺绑定)"}	source_header	unique_source_header	f	\N	\N	62	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
753	core	douyin_content_daily	column	\N	total_expense_rate_shop_bound	综合费比(店铺绑定)	douyin	\N	\N	{"单载体构成": "综合费比(店铺绑定)"}	source_header	unique_source_header	f	\N	\N	63	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
754	core	douyin_content_daily	column	\N	total_expense_rate_shop_promoted	综合费比(店铺被投)	douyin	\N	\N	{"单载体构成": "综合费比(店铺被投)"}	source_header	unique_source_header	f	\N	\N	64	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
755	core	douyin_content_daily	column	\N	total_expense_rate_net_refund_shop_bound	综合费比(剔除退款、店铺绑定)	douyin	\N	\N	{"单载体构成": "综合费比(剔除退款、店铺绑定)"}	source_header	unique_source_header	f	\N	\N	65	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
756	core	douyin_content_daily	column	\N	total_expense_rate_net_refund_shop_promoted	综合费比(剔除退款、店铺被投)	douyin	\N	\N	{"单载体构成": "综合费比(剔除退款、店铺被投)"}	source_header	unique_source_header	f	\N	\N	66	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
757	core	douyin_content_daily	column	\N	batch_id	导入批次ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	67	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
758	core	douyin_content_daily	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	68	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
759	core	douyin_content_daily	column	\N	source_row_number	源文件行号	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	69	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
691	core	douyin_content_daily	column	\N	row_id	数据行ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
694	core	douyin_content_daily	column	\N	selling_type	售卖类型	douyin	\N	\N	{"单载体构成": "售卖类型"}	source_header	unique_source_header	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
695	core	douyin_content_daily	column	\N	carrier_type	载体类型	douyin	\N	\N	{"单载体构成": "载体类型"}	source_header	unique_source_header	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
696	core	douyin_content_daily	column	\N	content_id	ID	douyin	\N	\N	{"单载体构成": "ID"}	source_header	unique_source_header	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
760	core	douyin_content_daily	column	\N	imported_at	写入时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	70	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
763	core	douyin_terminal_daily	column	\N	shop_id	店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
764	core	douyin_terminal_daily	column	\N	biz_date	日期	douyin	\N	\N	{"终端构成": "日期"}	source_header	unique_source_header	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
767	core	douyin_terminal_daily	column	\N	transaction_amount	成交金额	douyin	\N	\N	{"终端构成": "成交金额"}	source_header	unique_source_header	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
768	core	douyin_terminal_daily	column	\N	user_pay_amount	用户支付金额	douyin	\N	\N	{"终端构成": "用户支付金额"}	source_header	unique_source_header	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
769	core	douyin_terminal_daily	column	\N	settlement_amount	结算金额	douyin	\N	\N	{"终端构成": "结算金额"}	source_header	unique_source_header	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
770	core	douyin_terminal_daily	column	\N	transaction_order_count	成交订单数	douyin	\N	\N	{"终端构成": "成交订单数"}	source_header	unique_source_header	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
771	core	douyin_terminal_daily	column	\N	transaction_refund_amount_pay_time	成交退款金额(支付时间)	douyin	\N	\N	{"终端构成": "成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
772	core	douyin_terminal_daily	column	\N	refund_rate_pay_time	退款率(支付时间)	douyin	\N	\N	{"终端构成": "退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
773	core	douyin_terminal_daily	column	\N	product_exposure_count	商品曝光次数	douyin	\N	\N	{"终端构成": "商品曝光次数"}	source_header	unique_source_header	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
774	core	douyin_terminal_daily	column	\N	product_click_count	商品点击次数	douyin	\N	\N	{"终端构成": "商品点击次数"}	source_header	unique_source_header	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
775	core	douyin_terminal_daily	column	\N	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	douyin	\N	\N	{"终端构成": "商品曝光-点击转化率(次数)"}	source_header	unique_source_header	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
776	core	douyin_terminal_daily	column	\N	click_to_transaction_rate_events	商品点击-成交转化率(次数)	douyin	\N	\N	{"终端构成": "商品点击-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	15	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
777	core	douyin_terminal_daily	column	\N	smart_coupon_amount	智能优惠券金额	douyin	\N	\N	{"终端构成": "智能优惠券金额"}	source_header	unique_source_header	f	\N	\N	16	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
778	core	douyin_terminal_daily	column	\N	platform_subsidy_amount	平台补贴金额	douyin	\N	\N	{"终端构成": "平台补贴金额"}	source_header	unique_source_header	f	\N	\N	17	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
779	core	douyin_terminal_daily	column	\N	creator_subsidy_amount	达人补贴金额	douyin	\N	\N	{"终端构成": "达人补贴金额"}	source_header	unique_source_header	f	\N	\N	18	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
780	core	douyin_terminal_daily	column	\N	presale_deposit_amount	预售定金	douyin	\N	\N	{"终端构成": "预售定金"}	source_header	unique_source_header	f	\N	\N	19	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
781	core	douyin_terminal_daily	column	\N	transaction_item_count	成交件数	douyin	\N	\N	{"终端构成": "成交件数"}	source_header	unique_source_header	f	\N	\N	20	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
782	core	douyin_terminal_daily	column	\N	avg_item_amount	件单价	douyin	\N	\N	{"终端构成": "件单价"}	source_header	unique_source_header	f	\N	\N	21	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
783	core	douyin_terminal_daily	column	\N	settlement_amount_7d	7日结算金额	douyin	\N	\N	{"终端构成": "7日结算金额"}	source_header	unique_source_header	f	\N	\N	22	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
784	core	douyin_terminal_daily	column	\N	settlement_amount_14d	14日结算金额	douyin	\N	\N	{"终端构成": "14日结算金额"}	source_header	unique_source_header	f	\N	\N	23	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
785	core	douyin_terminal_daily	column	\N	settlement_amount_refund_time	结算金额(退款时间)	douyin	\N	\N	{"终端构成": "结算金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	24	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
786	core	douyin_terminal_daily	column	\N	ad_attributed_settlement_amount	投放贡献结算金额	douyin	\N	\N	{"终端构成": "投放贡献结算金额"}	source_header	unique_source_header	f	\N	\N	25	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
787	core	douyin_terminal_daily	column	\N	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	douyin	\N	\N	{"终端构成": "退款后用户支付金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	26	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
788	core	douyin_terminal_daily	column	\N	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	douyin	\N	\N	{"终端构成": "退款后智能优惠券金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	27	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
789	core	douyin_terminal_daily	column	\N	net_platform_subsidy_amount_pay_time	退款后平台补贴金额(支付时间)	douyin	\N	\N	{"终端构成": "退款后平台补贴金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	28	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
790	core	douyin_terminal_daily	column	\N	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	douyin	\N	\N	{"终端构成": "退款后达人补贴金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	29	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
791	core	douyin_terminal_daily	column	\N	refund_amount_pay_time	退款金额(支付时间)	douyin	\N	\N	{"终端构成": "退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	30	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
792	core	douyin_terminal_daily	column	\N	refund_order_count_pay_time	退款订单数(支付时间)	douyin	\N	\N	{"终端构成": "退款订单数(支付时间)"}	source_header	unique_source_header	f	\N	\N	31	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
793	core	douyin_terminal_daily	column	\N	transaction_refund_amount_refund_time	成交退款金额(退款时间)	douyin	\N	\N	{"终端构成": "成交退款金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	32	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
794	core	douyin_terminal_daily	column	\N	refund_amount_refund_time	退款金额(退款时间)	douyin	\N	\N	{"终端构成": "退款金额(退款时间)"}	source_header	unique_source_header	f	\N	\N	33	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
795	core	douyin_terminal_daily	column	\N	refund_order_count_refund_time	退款订单数(退款时间)	douyin	\N	\N	{"终端构成": "退款订单数(退款时间)"}	source_header	unique_source_header	f	\N	\N	34	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
796	core	douyin_terminal_daily	column	\N	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	douyin	\N	\N	{"终端构成": "1小时成交退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	35	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
797	core	douyin_terminal_daily	column	\N	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	douyin	\N	\N	{"终端构成": "1小时退款订单数(支付时间)"}	source_header	unique_source_header	f	\N	\N	36	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
798	core	douyin_terminal_daily	column	\N	one_hour_refund_rate_pay_time	1小时退款率(支付时间)	douyin	\N	\N	{"终端构成": "1小时退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	37	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
799	core	douyin_terminal_daily	column	\N	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	douyin	\N	\N	{"终端构成": "商品曝光-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	38	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
800	core	douyin_terminal_daily	column	\N	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	douyin	\N	\N	{"终端构成": "千次曝光用户支付金额"}	source_header	unique_source_header	f	\N	\N	39	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
801	core	douyin_terminal_daily	column	\N	batch_id	导入批次ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	40	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
762	core	douyin_terminal_daily	column	\N	row_id	数据行ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
765	core	douyin_terminal_daily	column	\N	terminal_type	终端类型	douyin	\N	\N	{"终端构成": "终端类型"}	source_header	unique_source_header	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
766	core	douyin_terminal_daily	column	\N	selling_type	售卖类型	douyin	\N	\N	{"终端构成": "售卖类型"}	source_header	unique_source_header	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
804	core	douyin_terminal_daily	column	\N	imported_at	写入时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	43	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
807	core	douyin_category_daily	column	\N	shop_id	店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
808	core	douyin_category_daily	column	\N	biz_date	日期	douyin	\N	\N	{"品类构成": "日期"}	source_header	unique_source_header	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
813	core	douyin_category_daily	column	\N	user_pay_amount	用户支付金额	douyin	\N	\N	{"品类构成": "用户支付金额"}	source_header	unique_source_header	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
814	core	douyin_category_daily	column	\N	avg_transaction_order_amount	成交笔单价	douyin	\N	\N	{"品类构成": "成交笔单价"}	source_header	unique_source_header	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
815	core	douyin_category_daily	column	\N	click_to_transaction_rate_events	商品点击-成交转化率(次数)	douyin	\N	\N	{"品类构成": "商品点击-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
816	core	douyin_category_daily	column	\N	refund_amount_pay_time	退款金额(支付时间)	douyin	\N	\N	{"品类构成": "退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
817	core	douyin_category_daily	column	\N	refund_rate_pay_time	退款率(支付时间)	douyin	\N	\N	{"品类构成": "退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
818	core	douyin_category_daily	column	\N	batch_id	导入批次ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
819	core	douyin_category_daily	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
820	core	douyin_category_daily	column	\N	source_row_number	源文件行号	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	15	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
806	core	douyin_category_daily	column	\N	row_id	数据行ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
809	core	douyin_category_daily	column	\N	category_level_1	一级类目	douyin	\N	\N	{"品类构成": "一级类目"}	source_header	unique_source_header	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
810	core	douyin_category_daily	column	\N	category_level_2	二级类目	douyin	\N	\N	{"品类构成": "二级类目"}	source_header	unique_source_header	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
811	core	douyin_category_daily	column	\N	category_level_3	三级类目	douyin	\N	\N	{"品类构成": "三级类目"}	source_header	unique_source_header	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
812	core	douyin_category_daily	column	\N	category_level_4	四级类目	douyin	\N	\N	{"品类构成": "四级类目"}	source_header	unique_source_header	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
821	core	douyin_category_daily	column	\N	imported_at	写入时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	16	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
824	core	douyin_product_daily	column	\N	shop_id	店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
825	core	douyin_product_daily	column	\N	biz_date	日期	douyin	\N	\N	{"商品构成": "日期"}	source_header	unique_source_header	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
826	core	douyin_product_daily	column	\N	product_name	商品名称	douyin	\N	\N	{"商品构成": "商品名称"}	source_header	unique_source_header	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
829	core	douyin_product_daily	column	\N	user_pay_amount	用户支付金额	douyin	\N	\N	{"商品构成": "用户支付金额"}	source_header	unique_source_header	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
830	core	douyin_product_daily	column	\N	avg_transaction_order_amount	成交笔单价	douyin	\N	\N	{"商品构成": "成交笔单价"}	source_header	unique_source_header	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
831	core	douyin_product_daily	column	\N	click_to_transaction_rate_events	商品点击-成交转化率(次数)	douyin	\N	\N	{"商品构成": "商品点击-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
832	core	douyin_product_daily	column	\N	refund_amount_pay_time	退款金额(支付时间)	douyin	\N	\N	{"商品构成": "退款金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
833	core	douyin_product_daily	column	\N	refund_rate_pay_time	退款率(支付时间)	douyin	\N	\N	{"商品构成": "退款率(支付时间)"}	source_header	unique_source_header	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
834	core	douyin_product_daily	column	\N	smart_coupon_amount	智能优惠券金额	douyin	\N	\N	{"商品构成": "智能优惠券金额"}	source_header	unique_source_header	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
835	core	douyin_product_daily	column	\N	platform_subsidy_amount	电商平台补贴金额	douyin	\N	\N	{"商品构成": "电商平台补贴金额"}	source_header	unique_source_header	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
836	core	douyin_product_daily	column	\N	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	douyin	\N	\N	{"商品构成": "退款后智能优惠券金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
837	core	douyin_product_daily	column	\N	net_platform_subsidy_amount_pay_time	退款后电商平台补贴金额(支付时间)	douyin	\N	\N	{"商品构成": "退款后电商平台补贴金额(支付时间)"}	source_header	unique_source_header	f	\N	\N	15	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
838	core	douyin_product_daily	column	\N	batch_id	导入批次ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	16	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
839	core	douyin_product_daily	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	17	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
840	core	douyin_product_daily	column	\N	source_row_number	源文件行号	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	18	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
823	core	douyin_product_daily	column	\N	row_id	数据行ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
827	core	douyin_product_daily	column	\N	product_id	商品编号	douyin	\N	\N	{"商品构成": "商品编号"}	source_header	unique_source_header	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
828	core	douyin_product_daily	column	\N	carrier_type	载体类型	douyin	\N	\N	{"商品构成": "载体类型"}	source_header	unique_source_header	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
841	core	douyin_product_daily	column	\N	imported_at	写入时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	19	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
844	core	douyin_price_band_daily	column	\N	shop_id	店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
845	core	douyin_price_band_daily	column	\N	biz_date	日期	douyin	\N	\N	{"价格带构成": "日期"}	source_header	unique_source_header	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
847	core	douyin_price_band_daily	column	\N	user_pay_amount	用户支付金额	douyin	\N	\N	{"价格带构成": "用户支付金额"}	source_header	unique_source_header	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
848	core	douyin_price_band_daily	column	\N	avg_transaction_order_amount	成交笔单价	douyin	\N	\N	{"价格带构成": "成交笔单价"}	source_header	unique_source_header	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
849	core	douyin_price_band_daily	column	\N	click_to_transaction_rate_events	商品点击-成交转化率(次数)	douyin	\N	\N	{"价格带构成": "商品点击-成交转化率(次数)"}	source_header	unique_source_header	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
850	core	douyin_price_band_daily	column	\N	batch_id	导入批次ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
851	core	douyin_price_band_daily	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
852	core	douyin_price_band_daily	column	\N	source_row_number	源文件行号	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
843	core	douyin_price_band_daily	column	\N	row_id	数据行ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
846	core	douyin_price_band_daily	column	\N	price_band	价格带	douyin	\N	\N	{"价格带构成": "价格带"}	source_header	unique_source_header	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
853	core	douyin_price_band_daily	column	\N	imported_at	写入时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
856	core	douyin_audience_daily	column	\N	shop_id	店铺ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
857	core	douyin_audience_daily	column	\N	biz_date	日期	douyin	\N	\N	{"人群构成": "日期"}	source_header	unique_source_header	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
860	core	douyin_audience_daily	column	\N	user_pay_amount	用户支付金额	douyin	\N	\N	{"人群构成": "用户支付金额"}	source_header	unique_source_header	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
861	core	douyin_audience_daily	column	\N	transaction_buyer_count	成交人数	douyin	\N	\N	{"人群构成": "成交人数"}	source_header	unique_source_header	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
862	core	douyin_audience_daily	column	\N	avg_customer_amount	客单价	douyin	\N	\N	{"人群构成": "客单价"}	source_header	unique_source_header	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
863	core	douyin_audience_daily	column	\N	transaction_order_count	成交订单数	douyin	\N	\N	{"人群构成": "成交订单数"}	source_header	unique_source_header	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
864	core	douyin_audience_daily	column	\N	repeat_user_repeat_rate	复购用户复购率	douyin	\N	\N	{"人群构成": "复购用户复购率"}	source_header	unique_source_header	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
865	core	douyin_audience_daily	column	\N	batch_id	导入批次ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
866	core	douyin_audience_daily	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
867	core	douyin_audience_daily	column	\N	source_row_number	源文件行号	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
855	core	douyin_audience_daily	column	\N	row_id	数据行ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
858	core	douyin_audience_daily	column	\N	audience_type	人群类型	douyin	\N	\N	{"人群构成": "人群类型"}	source_header	unique_source_header	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
859	core	douyin_audience_daily	column	\N	carrier_type	载体类型	douyin	\N	\N	{"人群构成": "载体类型"}	source_header	unique_source_header	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
868	core	douyin_audience_daily	column	\N	imported_at	写入时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
917	meta	metric_formula_rule	column	\N	target_table	目标正式表	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
918	meta	metric_formula_rule	column	\N	target_column_name_cn	目标字段中文名	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
919	meta	metric_formula_rule	column	\N	target_column_name	目标英文字段名	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
920	meta	metric_formula_rule	column	\N	metric_category	指标类别	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
921	meta	metric_formula_rule	column	\N	calculation_mode	计算模式	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
922	meta	metric_formula_rule	column	\N	formula_cn	业务公式	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
923	meta	metric_formula_rule	column	\N	numerator_expression	分子表达式	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
924	meta	metric_formula_rule	column	\N	denominator_expression	分母表达式	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
926	meta	metric_formula_rule	column	\N	single_row_formula	单行公式	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
927	meta	metric_formula_rule	column	\N	period_formula_sql	跨期SQL	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
931	meta	metric_formula_rule	column	\N	rule_status	规则状态	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	17	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
932	meta	metric_formula_rule	column	\N	display_format	展示格式	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	18	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
934	meta	metric_formula_rule	column	\N	notes	备注	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	20	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
915	meta	metric_formula_rule	column	\N	metric_rule_id	指标规则ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
916	meta	metric_formula_rule	column	\N	target_schema	目标Schema	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
925	meta	metric_formula_rule	column	\N	multiplier	计算倍率	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
928	meta	metric_formula_rule	column	\N	zero_denominator_rule	分母为0规则	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
929	meta	metric_formula_rule	column	\N	cross_period_recalculable	跨期可重算	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	15	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
930	meta	metric_formula_rule	column	\N	auto_use_allowed	允许自动采用	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	16	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
933	meta	metric_formula_rule	column	\N	mapping_version	映射版本	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	19	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
935	meta	metric_formula_rule	column	\N	created_at	创建时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	21	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
936	meta	metric_formula_rule	column	\N	verification_method	verification_method	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	22	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
937	meta	metric_formula_rule	column	\N	verification_period	verification_period	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	23	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
938	meta	metric_formula_rule	column	\N	verification_result	verification_result	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	24	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
941	meta	database_object_dictionary	column	\N	schema_name	schema_name	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	2	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
942	meta	database_object_dictionary	column	\N	object_name	英文对象名	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	3	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
944	meta	database_object_dictionary	column	\N	object_name_cn	中文对象名	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	5	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
945	meta	database_object_dictionary	column	\N	column_name	英文字段名	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	6	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
946	meta	database_object_dictionary	column	\N	column_name_cn	中文字段名	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	7	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
948	meta	database_object_dictionary	column	\N	source_sheet_name	源工作表名称	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	9	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
949	meta	database_object_dictionary	column	\N	source_field_name_cn	原始中文表头	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	10	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
950	meta	database_object_dictionary	column	\N	source_header_variants	source_header_variants	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	11	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
954	meta	database_object_dictionary	column	\N	override_reason	覆盖原因	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	15	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
955	meta	database_object_dictionary	column	\N	business_definition	业务含义	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	16	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
956	meta	database_object_dictionary	column	\N	display_order	字段顺序	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	17	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
940	meta	database_object_dictionary	column	\N	dictionary_id	字典ID	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	1	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
943	meta	database_object_dictionary	column	\N	object_type	对象类型	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	4	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
947	meta	database_object_dictionary	column	\N	source_platform	来源平台	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	8	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
951	meta	database_object_dictionary	column	\N	chinese_name_source	名称来源	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	12	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
952	meta	database_object_dictionary	column	\N	name_resolution_status	解析状态	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	13	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
953	meta	database_object_dictionary	column	\N	is_manual_override	人工覆盖标记	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	14	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
957	meta	database_object_dictionary	column	\N	visible_in_cn_view	中文视图可见	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	18	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
958	meta	database_object_dictionary	column	\N	mapping_version	映射版本	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	19	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
959	meta	database_object_dictionary	column	\N	enabled	是否启用	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	20	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
960	meta	database_object_dictionary	column	\N	created_at	创建时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	21	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
961	meta	database_object_dictionary	column	\N	updated_at	更新时间	douyin	\N	\N	\N	system_dictionary	system_field	f	\N	\N	22	t	V1.1	t	2026-08-07 16:42:56.155324+08	2026-08-07 16:42:56.155324+08
\.


--
-- Data for Name: field_mapping; Type: TABLE DATA; Schema: meta; Owner: postgres
--

COPY meta.field_mapping (mapping_id, source_sheet_name, source_sheet_code, source_column_order, source_column_name, target_schema, target_table, target_column_name, target_column_name_cn, target_data_type, field_category, aggregation_rule, transform_rule, value_unit, display_format, display_decimal_places, is_business_key, is_required_header, mapping_version, enabled, notes, created_at) FROM stdin;
2	成交概览	deal_overview	2	载体类型	core	douyin_deal_daily	carrier_type	载体类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
3	成交概览	deal_overview	3	投放时段	core	douyin_deal_daily	ad_period	投放时段	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
4	成交概览	deal_overview	4	用户支付金额	core	douyin_deal_daily	user_pay_amount	用户支付金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
5	成交概览	deal_overview	5	退款后用户支付金额(支付时间)	core	douyin_deal_daily	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
6	成交概览	deal_overview	6	智能优惠券金额	core	douyin_deal_daily	smart_coupon_amount	智能优惠券金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
7	成交概览	deal_overview	7	退款后智能优惠券金额(支付时间)	core	douyin_deal_daily	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
8	成交概览	deal_overview	8	平台补贴金额	core	douyin_deal_daily	platform_subsidy_amount	平台补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
9	成交概览	deal_overview	9	成交订单数	core	douyin_deal_daily	transaction_order_count	成交订单数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
10	成交概览	deal_overview	10	成交人数	core	douyin_deal_daily	transaction_buyer_count	成交人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
12	成交概览	deal_overview	12	成交金额	core	douyin_deal_daily	transaction_amount	成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
13	成交概览	deal_overview	13	净成交金额	core	douyin_deal_daily	net_transaction_amount	净成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
14	成交概览	deal_overview	14	退款金额(退款时间)	core	douyin_deal_daily	refund_amount_refund_time	退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
15	成交概览	deal_overview	15	成交退款金额(退款时间)	core	douyin_deal_daily	transaction_refund_amount_refund_time	成交退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
16	成交概览	deal_overview	16	退款订单数(退款时间)	core	douyin_deal_daily	refund_order_count_refund_time	退款订单数(退款时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
18	成交概览	deal_overview	18	退款金额(支付时间)	core	douyin_deal_daily	refund_amount_pay_time	退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
19	成交概览	deal_overview	19	成交退款金额(支付时间)	core	douyin_deal_daily	transaction_refund_amount_pay_time	成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
20	成交概览	deal_overview	20	退款订单数(支付时间)	core	douyin_deal_daily	refund_order_count_pay_time	退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
21	成交概览	deal_overview	21	商品曝光人数	core	douyin_deal_daily	product_exposure_user_count	商品曝光人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
22	成交概览	deal_overview	22	商品点击人数	core	douyin_deal_daily	product_click_user_count	商品点击人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
27	成交概览	deal_overview	27	商品曝光次数	core	douyin_deal_daily	product_exposure_count	商品曝光次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
28	成交概览	deal_overview	28	商品点击次数	core	douyin_deal_daily	product_click_count	商品点击次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
32	成交概览	deal_overview	32	发货用户支付金额(发货时间)	core	douyin_deal_daily	shipped_user_pay_amount_ship_time	发货用户支付金额(发货时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
34	成交概览	deal_overview	34	结算金额	core	douyin_deal_daily	settlement_amount	结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
35	成交概览	deal_overview	35	结算金额(退款时间)	core	douyin_deal_daily	settlement_amount_refund_time	结算金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
36	成交概览	deal_overview	36	7日结算金额	core	douyin_deal_daily	settlement_amount_7d	7日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
37	成交概览	deal_overview	37	14日结算金额	core	douyin_deal_daily	settlement_amount_14d	14日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
38	成交概览	deal_overview	38	退款后达人补贴金额(支付时间)	core	douyin_deal_daily	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
39	成交概览	deal_overview	39	达人补贴金额	core	douyin_deal_daily	creator_subsidy_amount	达人补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
40	成交概览	deal_overview	40	预售定金	core	douyin_deal_daily	presale_deposit_amount	预售定金	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
41	成交概览	deal_overview	41	成交件数	core	douyin_deal_daily	transaction_item_count	成交件数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
43	成交概览	deal_overview	43	净成交订单量	core	douyin_deal_daily	net_transaction_order_count	净成交订单量	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
48	成交概览	deal_overview	48	1小时成交退款金额(支付时间)	core	douyin_deal_daily	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
49	成交概览	deal_overview	49	1小时退款订单数(支付时间)	core	douyin_deal_daily	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
51	成交概览	deal_overview	51	退款后电商平台补贴金额(支付时间)	core	douyin_deal_daily	net_platform_subsidy_amount_pay_time	退款后平台补贴金额（支付时间）	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
52	自营成交	self_operated_deal	1	日期	core	douyin_deal_daily	biz_date	业务日期	DATE	业务日期	不聚合	按YYYYMMDD解析为DATE；非法日期阻止导入	number	\N	\N	t	t	V1.4	t	成交范围由工作表名称生成	2026-08-07 13:54:57.932418+08
53	自营成交	self_operated_deal	2	载体类型	core	douyin_deal_daily	carrier_type	载体类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
54	自营成交	self_operated_deal	3	投放时段	core	douyin_deal_daily	ad_period	投放时段	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
55	自营成交	self_operated_deal	4	用户支付金额	core	douyin_deal_daily	user_pay_amount	用户支付金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
56	自营成交	self_operated_deal	5	退款后用户支付金额(支付时间)	core	douyin_deal_daily	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
57	自营成交	self_operated_deal	6	智能优惠券金额	core	douyin_deal_daily	smart_coupon_amount	智能优惠券金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
58	自营成交	self_operated_deal	7	退款后智能优惠券金额(支付时间)	core	douyin_deal_daily	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
59	自营成交	self_operated_deal	8	平台补贴金额	core	douyin_deal_daily	platform_subsidy_amount	平台补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
60	自营成交	self_operated_deal	9	成交订单数	core	douyin_deal_daily	transaction_order_count	成交订单数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
61	自营成交	self_operated_deal	10	成交人数	core	douyin_deal_daily	transaction_buyer_count	成交人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
63	自营成交	self_operated_deal	12	成交金额	core	douyin_deal_daily	transaction_amount	成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
64	自营成交	self_operated_deal	13	净成交金额	core	douyin_deal_daily	net_transaction_amount	净成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
65	自营成交	self_operated_deal	14	退款金额(退款时间)	core	douyin_deal_daily	refund_amount_refund_time	退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
66	自营成交	self_operated_deal	15	成交退款金额(退款时间)	core	douyin_deal_daily	transaction_refund_amount_refund_time	成交退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
67	自营成交	self_operated_deal	16	退款订单数(退款时间)	core	douyin_deal_daily	refund_order_count_refund_time	退款订单数(退款时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
69	自营成交	self_operated_deal	18	退款金额(支付时间)	core	douyin_deal_daily	refund_amount_pay_time	退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
70	自营成交	self_operated_deal	19	成交退款金额(支付时间)	core	douyin_deal_daily	transaction_refund_amount_pay_time	成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
71	自营成交	self_operated_deal	20	退款订单数(支付时间)	core	douyin_deal_daily	refund_order_count_pay_time	退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
150	合作成交	partner_deal	48	1小时成交退款金额(支付时间)	core	douyin_deal_daily	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
72	自营成交	self_operated_deal	21	商品曝光人数	core	douyin_deal_daily	product_exposure_user_count	商品曝光人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
78	自营成交	self_operated_deal	27	商品曝光次数	core	douyin_deal_daily	product_exposure_count	商品曝光次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
79	自营成交	self_operated_deal	28	商品点击次数	core	douyin_deal_daily	product_click_count	商品点击次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
171	载体构成	carrier_mix	18	智能优惠券金额	core	douyin_carrier_daily	smart_coupon_amount	智能优惠券金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
73	自营成交	self_operated_deal	22	商品点击人数	core	douyin_deal_daily	product_click_user_count	商品点击人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
83	自营成交	self_operated_deal	32	发货用户支付金额(发货时间)	core	douyin_deal_daily	shipped_user_pay_amount_ship_time	发货用户支付金额(发货时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
85	自营成交	self_operated_deal	34	结算金额	core	douyin_deal_daily	settlement_amount	结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
86	自营成交	self_operated_deal	35	结算金额(退款时间)	core	douyin_deal_daily	settlement_amount_refund_time	结算金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
87	自营成交	self_operated_deal	36	7日结算金额	core	douyin_deal_daily	settlement_amount_7d	7日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
88	自营成交	self_operated_deal	37	14日结算金额	core	douyin_deal_daily	settlement_amount_14d	14日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
89	自营成交	self_operated_deal	38	退款后达人补贴金额(支付时间)	core	douyin_deal_daily	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
90	自营成交	self_operated_deal	39	达人补贴金额	core	douyin_deal_daily	creator_subsidy_amount	达人补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
91	自营成交	self_operated_deal	40	预售定金	core	douyin_deal_daily	presale_deposit_amount	预售定金	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
92	自营成交	self_operated_deal	41	成交件数	core	douyin_deal_daily	transaction_item_count	成交件数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
94	自营成交	self_operated_deal	43	净成交订单量	core	douyin_deal_daily	net_transaction_order_count	净成交订单量	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
99	自营成交	self_operated_deal	48	1小时成交退款金额(支付时间)	core	douyin_deal_daily	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
100	自营成交	self_operated_deal	49	1小时退款订单数(支付时间)	core	douyin_deal_daily	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
102	自营成交	self_operated_deal	51	退款后电商平台补贴金额(支付时间)	core	douyin_deal_daily	net_platform_subsidy_amount_pay_time	退款后平台补贴金额（支付时间）	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
103	合作成交	partner_deal	1	日期	core	douyin_deal_daily	biz_date	业务日期	DATE	业务日期	不聚合	按YYYYMMDD解析为DATE；非法日期阻止导入	number	\N	\N	t	t	V1.4	t	成交范围由工作表名称生成	2026-08-07 13:54:57.932418+08
104	合作成交	partner_deal	2	载体类型	core	douyin_deal_daily	carrier_type	载体类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
105	合作成交	partner_deal	3	投放时段	core	douyin_deal_daily	ad_period	投放时段	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
106	合作成交	partner_deal	4	用户支付金额	core	douyin_deal_daily	user_pay_amount	用户支付金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
107	合作成交	partner_deal	5	退款后用户支付金额(支付时间)	core	douyin_deal_daily	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
108	合作成交	partner_deal	6	智能优惠券金额	core	douyin_deal_daily	smart_coupon_amount	智能优惠券金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
109	合作成交	partner_deal	7	退款后智能优惠券金额(支付时间)	core	douyin_deal_daily	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
110	合作成交	partner_deal	8	平台补贴金额	core	douyin_deal_daily	platform_subsidy_amount	平台补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
111	合作成交	partner_deal	9	成交订单数	core	douyin_deal_daily	transaction_order_count	成交订单数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
112	合作成交	partner_deal	10	成交人数	core	douyin_deal_daily	transaction_buyer_count	成交人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
114	合作成交	partner_deal	12	成交金额	core	douyin_deal_daily	transaction_amount	成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
115	合作成交	partner_deal	13	净成交金额	core	douyin_deal_daily	net_transaction_amount	净成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
116	合作成交	partner_deal	14	退款金额(退款时间)	core	douyin_deal_daily	refund_amount_refund_time	退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
117	合作成交	partner_deal	15	成交退款金额(退款时间)	core	douyin_deal_daily	transaction_refund_amount_refund_time	成交退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
118	合作成交	partner_deal	16	退款订单数(退款时间)	core	douyin_deal_daily	refund_order_count_refund_time	退款订单数(退款时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
120	合作成交	partner_deal	18	退款金额(支付时间)	core	douyin_deal_daily	refund_amount_pay_time	退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
121	合作成交	partner_deal	19	成交退款金额(支付时间)	core	douyin_deal_daily	transaction_refund_amount_pay_time	成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
122	合作成交	partner_deal	20	退款订单数(支付时间)	core	douyin_deal_daily	refund_order_count_pay_time	退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
123	合作成交	partner_deal	21	商品曝光人数	core	douyin_deal_daily	product_exposure_user_count	商品曝光人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
124	合作成交	partner_deal	22	商品点击人数	core	douyin_deal_daily	product_click_user_count	商品点击人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
256	账号构成	account_mix	39	退款金额(退款时间)	core	douyin_account_daily	refund_amount_refund_time	退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
129	合作成交	partner_deal	27	商品曝光次数	core	douyin_deal_daily	product_exposure_count	商品曝光次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
130	合作成交	partner_deal	28	商品点击次数	core	douyin_deal_daily	product_click_count	商品点击次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
134	合作成交	partner_deal	32	发货用户支付金额(发货时间)	core	douyin_deal_daily	shipped_user_pay_amount_ship_time	发货用户支付金额(发货时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
282	单载体构成	content_mix	1	日期	core	douyin_content_daily	biz_date	业务日期	DATE	业务日期	不聚合	按YYYYMMDD解析为DATE；非法日期阻止导入	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
136	合作成交	partner_deal	34	结算金额	core	douyin_deal_daily	settlement_amount	结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
137	合作成交	partner_deal	35	结算金额(退款时间)	core	douyin_deal_daily	settlement_amount_refund_time	结算金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
138	合作成交	partner_deal	36	7日结算金额	core	douyin_deal_daily	settlement_amount_7d	7日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
139	合作成交	partner_deal	37	14日结算金额	core	douyin_deal_daily	settlement_amount_14d	14日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
140	合作成交	partner_deal	38	退款后达人补贴金额(支付时间)	core	douyin_deal_daily	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
141	合作成交	partner_deal	39	达人补贴金额	core	douyin_deal_daily	creator_subsidy_amount	达人补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
142	合作成交	partner_deal	40	预售定金	core	douyin_deal_daily	presale_deposit_amount	预售定金	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
143	合作成交	partner_deal	41	成交件数	core	douyin_deal_daily	transaction_item_count	成交件数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
145	合作成交	partner_deal	43	净成交订单量	core	douyin_deal_daily	net_transaction_order_count	净成交订单量	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
151	合作成交	partner_deal	49	1小时退款订单数(支付时间)	core	douyin_deal_daily	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
153	合作成交	partner_deal	51	退款后电商平台补贴金额(支付时间)	core	douyin_deal_daily	net_platform_subsidy_amount_pay_time	退款后平台补贴金额（支付时间）	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
154	载体构成	carrier_mix	1	日期	core	douyin_carrier_daily	biz_date	业务日期	DATE	业务日期	不聚合	按YYYYMMDD解析为DATE；非法日期阻止导入	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
155	载体构成	carrier_mix	2	自营/合作	core	douyin_carrier_daily	sale_scope	成交归属（自营/合作）	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
156	载体构成	carrier_mix	3	载体类型	core	douyin_carrier_daily	carrier_type	载体类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
157	载体构成	carrier_mix	4	账号/渠道	core	douyin_carrier_daily	account_channel	账号/渠道	VARCHAR(300)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
158	载体构成	carrier_mix	5	抖音号	core	douyin_carrier_daily	douyin_account_id	抖音号	VARCHAR(100)	标识字段	不聚合	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
159	载体构成	carrier_mix	6	成交金额	core	douyin_carrier_daily	transaction_amount	成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
160	载体构成	carrier_mix	7	用户支付金额	core	douyin_carrier_daily	user_pay_amount	用户支付金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
161	载体构成	carrier_mix	8	结算金额	core	douyin_carrier_daily	settlement_amount	结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
162	载体构成	carrier_mix	9	成交退款金额(支付时间)	core	douyin_carrier_daily	transaction_refund_amount_pay_time	成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
163	载体构成	carrier_mix	10	退款金额(支付时间)	core	douyin_carrier_daily	refund_amount_pay_time	退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
165	载体构成	carrier_mix	12	投放贡献成交金额	core	douyin_carrier_daily	ad_attributed_transaction_amount	投放贡献成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
167	载体构成	carrier_mix	14	投放消耗(店铺被投)	core	douyin_carrier_daily	ad_spend_shop_promoted	投放消耗(店铺被投)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
346	终端构成	terminal_mix	1	日期	core	douyin_terminal_daily	biz_date	业务日期	DATE	业务日期	不聚合	按YYYYMMDD解析为DATE；非法日期阻止导入	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
1	成交概览	deal_overview	1	日期	core	douyin_deal_daily	biz_date	业务日期	DATE	业务日期	不聚合	按YYYYMMDD解析为DATE；非法日期阻止导入	number	\N	\N	t	t	V1.4	t	成交范围由工作表名称生成	2026-08-07 13:54:57.932418+08
172	载体构成	carrier_mix	19	平台补贴金额	core	douyin_carrier_daily	platform_subsidy_amount	平台补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
173	载体构成	carrier_mix	20	达人补贴金额	core	douyin_carrier_daily	creator_subsidy_amount	达人补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
174	载体构成	carrier_mix	21	预售定金	core	douyin_carrier_daily	presale_deposit_amount	预售定金	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
176	载体构成	carrier_mix	23	成交件数	core	douyin_carrier_daily	transaction_item_count	成交件数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
178	载体构成	carrier_mix	25	成交人数	core	douyin_carrier_daily	transaction_buyer_count	成交人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
180	载体构成	carrier_mix	27	净成交金额	core	douyin_carrier_daily	net_transaction_amount	净成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
181	载体构成	carrier_mix	28	净成交订单量	core	douyin_carrier_daily	net_transaction_order_count	净成交订单量	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
182	载体构成	carrier_mix	29	7日结算金额	core	douyin_carrier_daily	settlement_amount_7d	7日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
183	载体构成	carrier_mix	30	14日结算金额	core	douyin_carrier_daily	settlement_amount_14d	14日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
184	载体构成	carrier_mix	31	结算金额(退款时间)	core	douyin_carrier_daily	settlement_amount_refund_time	结算金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
185	载体构成	carrier_mix	32	投放贡献结算金额	core	douyin_carrier_daily	ad_attributed_settlement_amount	投放贡献结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
186	载体构成	carrier_mix	33	退款后用户支付金额(支付时间)	core	douyin_carrier_daily	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
187	载体构成	carrier_mix	34	退款后智能优惠券金额(支付时间)	core	douyin_carrier_daily	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
188	载体构成	carrier_mix	35	退款后平台补贴金额(支付时间)	core	douyin_carrier_daily	net_platform_subsidy_amount_pay_time	退款后平台补贴金额（支付时间）	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
189	载体构成	carrier_mix	36	退款后达人补贴金额(支付时间)	core	douyin_carrier_daily	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
190	载体构成	carrier_mix	37	退款订单数(支付时间)	core	douyin_carrier_daily	refund_order_count_pay_time	退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
191	载体构成	carrier_mix	38	成交退款金额(退款时间)	core	douyin_carrier_daily	transaction_refund_amount_refund_time	成交退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
192	载体构成	carrier_mix	39	退款金额(退款时间)	core	douyin_carrier_daily	refund_amount_refund_time	退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
193	载体构成	carrier_mix	40	退款订单数(退款时间)	core	douyin_carrier_daily	refund_order_count_refund_time	退款订单数(退款时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
194	载体构成	carrier_mix	41	1小时成交退款金额(支付时间)	core	douyin_carrier_daily	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
195	载体构成	carrier_mix	42	1小时退款订单数(支付时间)	core	douyin_carrier_daily	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
197	载体构成	carrier_mix	44	投放贡献成交退款金额(支付时间)	core	douyin_carrier_daily	ad_attributed_transaction_refund_amount_pay_time	投放贡献成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
199	载体构成	carrier_mix	46	商品曝光次数	core	douyin_carrier_daily	product_exposure_count	商品曝光次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
200	载体构成	carrier_mix	47	商品点击次数	core	douyin_carrier_daily	product_click_count	商品点击次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
204	载体构成	carrier_mix	51	商品曝光人数	core	douyin_carrier_daily	product_exposure_user_count	商品曝光人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
205	载体构成	carrier_mix	52	商品点击人数	core	douyin_carrier_daily	product_click_user_count	商品点击人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
208	载体构成	carrier_mix	55	投放消耗(店铺绑定)	core	douyin_carrier_daily	ad_spend_shop_bound	投放消耗(店铺绑定)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
209	载体构成	carrier_mix	56	平台佣金(结算口径)	core	douyin_carrier_daily	platform_commission_settlement	平台佣金(结算口径)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
210	载体构成	carrier_mix	57	达人佣金(结算口径)	core	douyin_carrier_daily	creator_commission_settlement	达人佣金(结算口径)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
218	账号构成	account_mix	1	日期	core	douyin_account_daily	biz_date	业务日期	DATE	业务日期	不聚合	按YYYYMMDD解析为DATE；非法日期阻止导入	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
219	账号构成	account_mix	2	账号名称	core	douyin_account_daily	account_name	账号名称	VARCHAR(300)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
220	账号构成	account_mix	3	账号类型	core	douyin_account_daily	account_type	账号类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
221	账号构成	account_mix	4	自营/合作	core	douyin_account_daily	sale_scope	成交归属（自营/合作）	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
222	账号构成	account_mix	5	抖音号	core	douyin_account_daily	douyin_account_id	抖音号	VARCHAR(100)	标识字段	不聚合	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
223	账号构成	account_mix	6	成交金额	core	douyin_account_daily	transaction_amount	成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
224	账号构成	account_mix	7	用户支付金额	core	douyin_account_daily	user_pay_amount	用户支付金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
225	账号构成	account_mix	8	结算金额	core	douyin_account_daily	settlement_amount	结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
226	账号构成	account_mix	9	成交退款金额(支付时间)	core	douyin_account_daily	transaction_refund_amount_pay_time	成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
227	账号构成	account_mix	10	退款金额(支付时间)	core	douyin_account_daily	refund_amount_pay_time	退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
229	账号构成	account_mix	12	投放贡献成交金额	core	douyin_account_daily	ad_attributed_transaction_amount	投放贡献成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
231	账号构成	account_mix	14	投放消耗(店铺被投)	core	douyin_account_daily	ad_spend_shop_promoted	投放消耗(店铺被投)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
235	账号构成	account_mix	18	智能优惠券金额	core	douyin_account_daily	smart_coupon_amount	智能优惠券金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
236	账号构成	account_mix	19	平台补贴金额	core	douyin_account_daily	platform_subsidy_amount	平台补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
237	账号构成	account_mix	20	达人补贴金额	core	douyin_account_daily	creator_subsidy_amount	达人补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
238	账号构成	account_mix	21	预售定金	core	douyin_account_daily	presale_deposit_amount	预售定金	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
239	账号构成	account_mix	22	成交订单数	core	douyin_account_daily	transaction_order_count	成交订单数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
240	账号构成	account_mix	23	成交件数	core	douyin_account_daily	transaction_item_count	成交件数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
242	账号构成	account_mix	25	成交人数	core	douyin_account_daily	transaction_buyer_count	成交人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
244	账号构成	account_mix	27	净成交金额	core	douyin_account_daily	net_transaction_amount	净成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
245	账号构成	account_mix	28	净成交订单量	core	douyin_account_daily	net_transaction_order_count	净成交订单量	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
246	账号构成	account_mix	29	7日结算金额	core	douyin_account_daily	settlement_amount_7d	7日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
247	账号构成	account_mix	30	14日结算金额	core	douyin_account_daily	settlement_amount_14d	14日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
248	账号构成	account_mix	31	结算金额(退款时间)	core	douyin_account_daily	settlement_amount_refund_time	结算金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
249	账号构成	account_mix	32	投放贡献结算金额	core	douyin_account_daily	ad_attributed_settlement_amount	投放贡献结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
250	账号构成	account_mix	33	退款后用户支付金额(支付时间)	core	douyin_account_daily	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
251	账号构成	account_mix	34	退款后智能优惠券金额(支付时间)	core	douyin_account_daily	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
252	账号构成	account_mix	35	退款后平台补贴金额(支付时间)	core	douyin_account_daily	net_platform_subsidy_amount_pay_time	退款后平台补贴金额（支付时间）	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
253	账号构成	account_mix	36	退款后达人补贴金额(支付时间)	core	douyin_account_daily	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
254	账号构成	account_mix	37	退款订单数(支付时间)	core	douyin_account_daily	refund_order_count_pay_time	退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
255	账号构成	account_mix	38	成交退款金额(退款时间)	core	douyin_account_daily	transaction_refund_amount_refund_time	成交退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
257	账号构成	account_mix	40	退款订单数(退款时间)	core	douyin_account_daily	refund_order_count_refund_time	退款订单数(退款时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
258	账号构成	account_mix	41	1小时成交退款金额(支付时间)	core	douyin_account_daily	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
259	账号构成	account_mix	42	1小时退款订单数(支付时间)	core	douyin_account_daily	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
261	账号构成	account_mix	44	投放贡献成交退款金额(支付时间)	core	douyin_account_daily	ad_attributed_transaction_refund_amount_pay_time	投放贡献成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
263	账号构成	account_mix	46	商品曝光次数	core	douyin_account_daily	product_exposure_count	商品曝光次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
264	账号构成	account_mix	47	商品点击次数	core	douyin_account_daily	product_click_count	商品点击次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
268	账号构成	account_mix	51	商品曝光人数	core	douyin_account_daily	product_exposure_user_count	商品曝光人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
269	账号构成	account_mix	52	商品点击人数	core	douyin_account_daily	product_click_user_count	商品点击人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
272	账号构成	account_mix	55	投放消耗(店铺绑定)	core	douyin_account_daily	ad_spend_shop_bound	投放消耗(店铺绑定)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
273	账号构成	account_mix	56	平台佣金(结算口径)	core	douyin_account_daily	platform_commission_settlement	平台佣金(结算口径)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
274	账号构成	account_mix	57	达人佣金(结算口径)	core	douyin_account_daily	creator_commission_settlement	达人佣金(结算口径)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
283	单载体构成	content_mix	2	售卖类型	core	douyin_content_daily	selling_type	售卖类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
284	单载体构成	content_mix	3	载体类型	core	douyin_content_daily	carrier_type	载体类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
285	单载体构成	content_mix	4	ID	core	douyin_content_daily	content_id	内容或载体ID	VARCHAR(128)	标识字段	不聚合	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
286	单载体构成	content_mix	5	标题/名称	core	douyin_content_daily	content_title	内容或载体标题/名称	TEXT	维度字段	分组维度	按文本读取并TRIM；空白转NULL	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
287	单载体构成	content_mix	6	成交金额	core	douyin_content_daily	transaction_amount	成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
288	单载体构成	content_mix	7	用户支付金额	core	douyin_content_daily	user_pay_amount	用户支付金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
289	单载体构成	content_mix	8	结算金额	core	douyin_content_daily	settlement_amount	结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
290	单载体构成	content_mix	9	成交退款金额(支付时间)	core	douyin_content_daily	transaction_refund_amount_pay_time	成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
291	单载体构成	content_mix	10	退款金额(支付时间)	core	douyin_content_daily	refund_amount_pay_time	退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
293	单载体构成	content_mix	12	投放贡献成交金额	core	douyin_content_daily	ad_attributed_transaction_amount	投放贡献成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
295	单载体构成	content_mix	14	投放消耗(店铺被投)	core	douyin_content_daily	ad_spend_shop_promoted	投放消耗(店铺被投)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
299	单载体构成	content_mix	18	智能优惠券金额	core	douyin_content_daily	smart_coupon_amount	智能优惠券金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
300	单载体构成	content_mix	19	平台补贴金额	core	douyin_content_daily	platform_subsidy_amount	平台补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
301	单载体构成	content_mix	20	达人补贴金额	core	douyin_content_daily	creator_subsidy_amount	达人补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
302	单载体构成	content_mix	21	预售定金	core	douyin_content_daily	presale_deposit_amount	预售定金	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
303	单载体构成	content_mix	22	成交订单数	core	douyin_content_daily	transaction_order_count	成交订单数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
304	单载体构成	content_mix	23	成交件数	core	douyin_content_daily	transaction_item_count	成交件数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
306	单载体构成	content_mix	25	成交人数	core	douyin_content_daily	transaction_buyer_count	成交人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
308	单载体构成	content_mix	27	净成交金额	core	douyin_content_daily	net_transaction_amount	净成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
309	单载体构成	content_mix	28	净成交订单量	core	douyin_content_daily	net_transaction_order_count	净成交订单量	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
310	单载体构成	content_mix	29	7日结算金额	core	douyin_content_daily	settlement_amount_7d	7日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
311	单载体构成	content_mix	30	14日结算金额	core	douyin_content_daily	settlement_amount_14d	14日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
312	单载体构成	content_mix	31	结算金额(退款时间)	core	douyin_content_daily	settlement_amount_refund_time	结算金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
313	单载体构成	content_mix	32	投放贡献结算金额	core	douyin_content_daily	ad_attributed_settlement_amount	投放贡献结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
314	单载体构成	content_mix	33	退款后用户支付金额(支付时间)	core	douyin_content_daily	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
315	单载体构成	content_mix	34	退款后智能优惠券金额(支付时间)	core	douyin_content_daily	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
316	单载体构成	content_mix	35	退款后平台补贴金额(支付时间)	core	douyin_content_daily	net_platform_subsidy_amount_pay_time	退款后平台补贴金额（支付时间）	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
317	单载体构成	content_mix	36	退款后达人补贴金额(支付时间)	core	douyin_content_daily	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
318	单载体构成	content_mix	37	退款订单数(支付时间)	core	douyin_content_daily	refund_order_count_pay_time	退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
319	单载体构成	content_mix	38	成交退款金额(退款时间)	core	douyin_content_daily	transaction_refund_amount_refund_time	成交退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
320	单载体构成	content_mix	39	退款金额(退款时间)	core	douyin_content_daily	refund_amount_refund_time	退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
321	单载体构成	content_mix	40	退款订单数(退款时间)	core	douyin_content_daily	refund_order_count_refund_time	退款订单数(退款时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
322	单载体构成	content_mix	41	1小时成交退款金额(支付时间)	core	douyin_content_daily	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
323	单载体构成	content_mix	42	1小时退款订单数(支付时间)	core	douyin_content_daily	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
325	单载体构成	content_mix	44	投放贡献成交退款金额(支付时间)	core	douyin_content_daily	ad_attributed_transaction_refund_amount_pay_time	投放贡献成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
327	单载体构成	content_mix	46	商品曝光次数	core	douyin_content_daily	product_exposure_count	商品曝光次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
328	单载体构成	content_mix	47	商品点击次数	core	douyin_content_daily	product_click_count	商品点击次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
332	单载体构成	content_mix	51	商品曝光人数	core	douyin_content_daily	product_exposure_user_count	商品曝光人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
333	单载体构成	content_mix	52	商品点击人数	core	douyin_content_daily	product_click_user_count	商品点击人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
175	载体构成	carrier_mix	22	成交订单数	core	douyin_carrier_daily	transaction_order_count	成交订单数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
336	单载体构成	content_mix	55	投放消耗(店铺绑定)	core	douyin_content_daily	ad_spend_shop_bound	投放消耗(店铺绑定)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
337	单载体构成	content_mix	56	平台佣金(结算口径)	core	douyin_content_daily	platform_commission_settlement	平台佣金(结算口径)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
338	单载体构成	content_mix	57	达人佣金(结算口径)	core	douyin_content_daily	creator_commission_settlement	达人佣金(结算口径)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
347	终端构成	terminal_mix	2	终端类型	core	douyin_terminal_daily	terminal_type	终端类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
348	终端构成	terminal_mix	3	售卖类型	core	douyin_terminal_daily	selling_type	售卖类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
349	终端构成	terminal_mix	4	成交金额	core	douyin_terminal_daily	transaction_amount	成交金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
350	终端构成	terminal_mix	5	用户支付金额	core	douyin_terminal_daily	user_pay_amount	用户支付金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
351	终端构成	terminal_mix	6	结算金额	core	douyin_terminal_daily	settlement_amount	结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
352	终端构成	terminal_mix	7	成交订单数	core	douyin_terminal_daily	transaction_order_count	成交订单数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
353	终端构成	terminal_mix	8	成交退款金额(支付时间)	core	douyin_terminal_daily	transaction_refund_amount_pay_time	成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
355	终端构成	terminal_mix	10	商品曝光次数	core	douyin_terminal_daily	product_exposure_count	商品曝光次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
356	终端构成	terminal_mix	11	商品点击次数	core	douyin_terminal_daily	product_click_count	商品点击次数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
359	终端构成	terminal_mix	14	智能优惠券金额	core	douyin_terminal_daily	smart_coupon_amount	智能优惠券金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
360	终端构成	terminal_mix	15	平台补贴金额	core	douyin_terminal_daily	platform_subsidy_amount	平台补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
361	终端构成	terminal_mix	16	达人补贴金额	core	douyin_terminal_daily	creator_subsidy_amount	达人补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
362	终端构成	terminal_mix	17	预售定金	core	douyin_terminal_daily	presale_deposit_amount	预售定金	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
363	终端构成	terminal_mix	18	成交件数	core	douyin_terminal_daily	transaction_item_count	成交件数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
365	终端构成	terminal_mix	20	7日结算金额	core	douyin_terminal_daily	settlement_amount_7d	7日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
366	终端构成	terminal_mix	21	14日结算金额	core	douyin_terminal_daily	settlement_amount_14d	14日结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
367	终端构成	terminal_mix	22	结算金额(退款时间)	core	douyin_terminal_daily	settlement_amount_refund_time	结算金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
368	终端构成	terminal_mix	23	投放贡献结算金额	core	douyin_terminal_daily	ad_attributed_settlement_amount	投放贡献结算金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
369	终端构成	terminal_mix	24	退款后用户支付金额(支付时间)	core	douyin_terminal_daily	net_user_pay_amount_pay_time	退款后用户支付金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
370	终端构成	terminal_mix	25	退款后智能优惠券金额(支付时间)	core	douyin_terminal_daily	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
371	终端构成	terminal_mix	26	退款后平台补贴金额(支付时间)	core	douyin_terminal_daily	net_platform_subsidy_amount_pay_time	退款后平台补贴金额（支付时间）	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
372	终端构成	terminal_mix	27	退款后达人补贴金额(支付时间)	core	douyin_terminal_daily	net_creator_subsidy_amount_pay_time	退款后达人补贴金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
373	终端构成	terminal_mix	28	退款金额(支付时间)	core	douyin_terminal_daily	refund_amount_pay_time	退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
374	终端构成	terminal_mix	29	退款订单数(支付时间)	core	douyin_terminal_daily	refund_order_count_pay_time	退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
375	终端构成	terminal_mix	30	成交退款金额(退款时间)	core	douyin_terminal_daily	transaction_refund_amount_refund_time	成交退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
376	终端构成	terminal_mix	31	退款金额(退款时间)	core	douyin_terminal_daily	refund_amount_refund_time	退款金额(退款时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
377	终端构成	terminal_mix	32	退款订单数(退款时间)	core	douyin_terminal_daily	refund_order_count_refund_time	退款订单数(退款时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
378	终端构成	terminal_mix	33	1小时成交退款金额(支付时间)	core	douyin_terminal_daily	one_hour_transaction_refund_amount_pay_time	1小时成交退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
379	终端构成	terminal_mix	34	1小时退款订单数(支付时间)	core	douyin_terminal_daily	one_hour_refund_order_count_pay_time	1小时退款订单数(支付时间)	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
384	品类构成	category_mix	2	一级类目	core	douyin_category_daily	category_level_1	一级类目	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
385	品类构成	category_mix	3	二级类目	core	douyin_category_daily	category_level_2	二级类目	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
386	品类构成	category_mix	4	三级类目	core	douyin_category_daily	category_level_3	三级类目	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
387	品类构成	category_mix	5	四级类目	core	douyin_category_daily	category_level_4	四级类目	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
388	品类构成	category_mix	6	用户支付金额	core	douyin_category_daily	user_pay_amount	用户支付金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
393	商品构成	product_mix	1	日期	core	douyin_product_daily	biz_date	业务日期	DATE	业务日期	不聚合	按YYYYMMDD解析为DATE；非法日期阻止导入	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
394	商品构成	product_mix	2	商品名称	core	douyin_product_daily	product_name	商品名称	TEXT	维度字段	分组维度	按文本读取并TRIM；空白转NULL	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
395	商品构成	product_mix	3	商品编号	core	douyin_product_daily	product_id	商品编号	VARCHAR(100)	标识字段	不聚合	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
411	人群构成	audience_mix	1	日期	core	douyin_audience_daily	biz_date	业务日期	DATE	业务日期	不聚合	按YYYYMMDD解析为DATE；非法日期阻止导入	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
412	人群构成	audience_mix	2	人群类型	core	douyin_audience_daily	audience_type	人群类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
413	人群构成	audience_mix	3	载体类型	core	douyin_audience_daily	carrier_type	载体类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
414	人群构成	audience_mix	4	用户支付金额	core	douyin_audience_daily	user_pay_amount	用户支付金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
415	人群构成	audience_mix	5	成交人数	core	douyin_audience_daily	transaction_buyer_count	成交人数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
417	人群构成	audience_mix	7	成交订单数	core	douyin_audience_daily	transaction_order_count	成交订单数	BIGINT	可累加计数指标	SUM	空白转NULL；转为整数	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
17	成交概览	deal_overview	17	退款率(支付时间)	core	douyin_deal_daily	refund_rate_pay_time	退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
23	成交概览	deal_overview	23	商品曝光-点击转化率(人数)	core	douyin_deal_daily	exposure_to_click_rate_users	商品曝光-点击转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_user_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
24	成交概览	deal_overview	24	商品点击-成交转化率(人数)	core	douyin_deal_daily	click_to_transaction_rate_users	商品点击-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_click_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
25	成交概览	deal_overview	25	商品曝光-成交转化率(人数)	core	douyin_deal_daily	exposure_to_transaction_rate_users	商品曝光-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
26	成交概览	deal_overview	26	千次曝光用户支付金额	core	douyin_deal_daily	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
29	成交概览	deal_overview	29	商品曝光-点击转化率(次数)	core	douyin_deal_daily	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
30	成交概览	deal_overview	30	商品点击-成交转化率(次数)	core	douyin_deal_daily	click_to_transaction_rate_events	商品点击-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
31	成交概览	deal_overview	31	商品曝光-成交转化率(次数)	core	douyin_deal_daily	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
33	成交概览	deal_overview	33	两日内发货率	core	douyin_deal_daily	ship_within_2_days_rate	两日内发货率	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
42	成交概览	deal_overview	42	件单价	core	douyin_deal_daily	avg_item_amount	件单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
416	人群构成	audience_mix	6	客单价	core	douyin_audience_daily	avg_customer_amount	客单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
44	成交概览	deal_overview	44	发货前退款率(支付时间)	core	douyin_deal_daily	pre_shipment_refund_rate_pay_time	发货前退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
45	成交概览	deal_overview	45	未收货退款率(支付时间)	core	douyin_deal_daily	unreceived_refund_rate_pay_time	未收货退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
46	成交概览	deal_overview	46	已收货退款率(支付时间)	core	douyin_deal_daily	received_refund_rate_pay_time	已收货退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
47	成交概览	deal_overview	47	已收货退货退款率(支付时间)	core	douyin_deal_daily	received_return_refund_rate_pay_time	已收货退货退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
50	成交概览	deal_overview	50	1小时成交退款率(支付时间)	core	douyin_deal_daily	one_hour_refund_rate_pay_time	1小时退款率（支付时间）	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
68	自营成交	self_operated_deal	17	退款率(支付时间)	core	douyin_deal_daily	refund_rate_pay_time	退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
74	自营成交	self_operated_deal	23	商品曝光-点击转化率(人数)	core	douyin_deal_daily	exposure_to_click_rate_users	商品曝光-点击转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_user_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
75	自营成交	self_operated_deal	24	商品点击-成交转化率(人数)	core	douyin_deal_daily	click_to_transaction_rate_users	商品点击-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_click_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
76	自营成交	self_operated_deal	25	商品曝光-成交转化率(人数)	core	douyin_deal_daily	exposure_to_transaction_rate_users	商品曝光-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
77	自营成交	self_operated_deal	26	千次曝光用户支付金额	core	douyin_deal_daily	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
80	自营成交	self_operated_deal	29	商品曝光-点击转化率(次数)	core	douyin_deal_daily	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
305	单载体构成	content_mix	24	件单价	core	douyin_content_daily	avg_item_amount	件单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
81	自营成交	self_operated_deal	30	商品点击-成交转化率(次数)	core	douyin_deal_daily	click_to_transaction_rate_events	商品点击-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
82	自营成交	self_operated_deal	31	商品曝光-成交转化率(次数)	core	douyin_deal_daily	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
84	自营成交	self_operated_deal	33	两日内发货率	core	douyin_deal_daily	ship_within_2_days_rate	两日内发货率	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
93	自营成交	self_operated_deal	42	件单价	core	douyin_deal_daily	avg_item_amount	件单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
95	自营成交	self_operated_deal	44	发货前退款率(支付时间)	core	douyin_deal_daily	pre_shipment_refund_rate_pay_time	发货前退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
96	自营成交	self_operated_deal	45	未收货退款率(支付时间)	core	douyin_deal_daily	unreceived_refund_rate_pay_time	未收货退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
97	自营成交	self_operated_deal	46	已收货退款率(支付时间)	core	douyin_deal_daily	received_refund_rate_pay_time	已收货退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
98	自营成交	self_operated_deal	47	已收货退货退款率(支付时间)	core	douyin_deal_daily	received_return_refund_rate_pay_time	已收货退货退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
101	自营成交	self_operated_deal	50	1小时成交退款率(支付时间)	core	douyin_deal_daily	one_hour_refund_rate_pay_time	1小时退款率（支付时间）	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
113	合作成交	partner_deal	11	客单价	core	douyin_deal_daily	avg_customer_amount	客单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
119	合作成交	partner_deal	17	退款率(支付时间)	core	douyin_deal_daily	refund_rate_pay_time	退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
125	合作成交	partner_deal	23	商品曝光-点击转化率(人数)	core	douyin_deal_daily	exposure_to_click_rate_users	商品曝光-点击转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_user_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
126	合作成交	partner_deal	24	商品点击-成交转化率(人数)	core	douyin_deal_daily	click_to_transaction_rate_users	商品点击-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_click_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
127	合作成交	partner_deal	25	商品曝光-成交转化率(人数)	core	douyin_deal_daily	exposure_to_transaction_rate_users	商品曝光-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
128	合作成交	partner_deal	26	千次曝光用户支付金额	core	douyin_deal_daily	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
131	合作成交	partner_deal	29	商品曝光-点击转化率(次数)	core	douyin_deal_daily	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
132	合作成交	partner_deal	30	商品点击-成交转化率(次数)	core	douyin_deal_daily	click_to_transaction_rate_events	商品点击-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
133	合作成交	partner_deal	31	商品曝光-成交转化率(次数)	core	douyin_deal_daily	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
135	合作成交	partner_deal	33	两日内发货率	core	douyin_deal_daily	ship_within_2_days_rate	两日内发货率	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
146	合作成交	partner_deal	44	发货前退款率(支付时间)	core	douyin_deal_daily	pre_shipment_refund_rate_pay_time	发货前退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
147	合作成交	partner_deal	45	未收货退款率(支付时间)	core	douyin_deal_daily	unreceived_refund_rate_pay_time	未收货退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
148	合作成交	partner_deal	46	已收货退款率(支付时间)	core	douyin_deal_daily	received_refund_rate_pay_time	已收货退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
149	合作成交	partner_deal	47	已收货退货退款率(支付时间)	core	douyin_deal_daily	received_return_refund_rate_pay_time	已收货退货退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
335	单载体构成	content_mix	54	千次曝光用户支付金额	core	douyin_content_daily	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
152	合作成交	partner_deal	50	1小时成交退款率(支付时间)	core	douyin_deal_daily	one_hour_refund_rate_pay_time	1小时退款率（支付时间）	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
164	载体构成	carrier_mix	11	退款率(支付时间)	core	douyin_carrier_daily	refund_rate_pay_time	退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
166	载体构成	carrier_mix	13	投放贡献成交占比	core	douyin_carrier_daily	ad_attributed_transaction_share	投放贡献成交占比	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_attributed_transaction_amount) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
168	载体构成	carrier_mix	15	投放费比(剔除退款、店铺被投)	core	douyin_carrier_daily	ad_spend_rate_net_refund_shop_promoted	投放费比(剔除退款、店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_promoted) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
169	载体构成	carrier_mix	16	商品曝光-点击转化率(人数)	core	douyin_carrier_daily	exposure_to_click_rate_users	商品曝光-点击转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_user_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
170	载体构成	carrier_mix	17	商品点击-成交转化率(人数)	core	douyin_carrier_daily	click_to_transaction_rate_users	商品点击-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_click_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
177	载体构成	carrier_mix	24	件单价	core	douyin_carrier_daily	avg_item_amount	件单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
179	载体构成	carrier_mix	26	客单价	core	douyin_carrier_daily	avg_customer_amount	客单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
196	载体构成	carrier_mix	43	1小时退款率(支付时间)	core	douyin_carrier_daily	one_hour_refund_rate_pay_time	1小时退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
198	载体构成	carrier_mix	45	投放部分退款率(支付时间)	core	douyin_carrier_daily	ad_attributed_refund_rate_pay_time	投放部分退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_attributed_transaction_refund_amount_pay_time) / NULLIF(SUM(ad_attributed_transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
201	载体构成	carrier_mix	48	商品曝光-点击转化率(次数)	core	douyin_carrier_daily	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
202	载体构成	carrier_mix	49	商品点击-成交转化率(次数)	core	douyin_carrier_daily	click_to_transaction_rate_events	商品点击-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
203	载体构成	carrier_mix	50	商品曝光-成交转化率(次数)	core	douyin_carrier_daily	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
206	载体构成	carrier_mix	53	商品曝光-成交转化率(人数)	core	douyin_carrier_daily	exposure_to_transaction_rate_users	商品曝光-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
207	载体构成	carrier_mix	54	千次曝光用户支付金额	core	douyin_carrier_daily	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
211	载体构成	carrier_mix	58	投放费比(店铺绑定)	core	douyin_carrier_daily	ad_spend_rate_shop_bound	投放费比(店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_bound) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
212	载体构成	carrier_mix	59	投放费比(店铺被投)	core	douyin_carrier_daily	ad_spend_rate_shop_promoted	投放费比(店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_promoted) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
213	载体构成	carrier_mix	60	投放费比(剔除退款、店铺绑定)	core	douyin_carrier_daily	ad_spend_rate_net_refund_shop_bound	投放费比(剔除退款、店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_bound) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
214	载体构成	carrier_mix	61	综合费比(店铺绑定)	core	douyin_carrier_daily	total_expense_rate_shop_bound	综合费比(店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
215	载体构成	carrier_mix	62	综合费比(店铺被投)	core	douyin_carrier_daily	total_expense_rate_shop_promoted	综合费比(店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
216	载体构成	carrier_mix	63	综合费比(剔除退款、店铺绑定)	core	douyin_carrier_daily	total_expense_rate_net_refund_shop_bound	综合费比(剔除退款、店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
217	载体构成	carrier_mix	64	综合费比(剔除退款、店铺被投)	core	douyin_carrier_daily	total_expense_rate_net_refund_shop_promoted	综合费比(剔除退款、店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
228	账号构成	account_mix	11	退款率(支付时间)	core	douyin_account_daily	refund_rate_pay_time	退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
383	品类构成	category_mix	1	日期	core	douyin_category_daily	biz_date	业务日期	DATE	业务日期	不聚合	按YYYYMMDD解析为DATE；非法日期阻止导入	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
230	账号构成	account_mix	13	投放贡献成交占比	core	douyin_account_daily	ad_attributed_transaction_share	投放贡献成交占比	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_attributed_transaction_amount) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
232	账号构成	account_mix	15	投放费比(剔除退款、店铺被投)	core	douyin_account_daily	ad_spend_rate_net_refund_shop_promoted	投放费比(剔除退款、店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_promoted) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
233	账号构成	account_mix	16	商品曝光-点击转化率(人数)	core	douyin_account_daily	exposure_to_click_rate_users	商品曝光-点击转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_user_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
234	账号构成	account_mix	17	商品点击-成交转化率(人数)	core	douyin_account_daily	click_to_transaction_rate_users	商品点击-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_click_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
243	账号构成	account_mix	26	客单价	core	douyin_account_daily	avg_customer_amount	客单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
260	账号构成	account_mix	43	1小时退款率(支付时间)	core	douyin_account_daily	one_hour_refund_rate_pay_time	1小时退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
262	账号构成	account_mix	45	投放部分退款率(支付时间)	core	douyin_account_daily	ad_attributed_refund_rate_pay_time	投放部分退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_attributed_transaction_refund_amount_pay_time) / NULLIF(SUM(ad_attributed_transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
265	账号构成	account_mix	48	商品曝光-点击转化率(次数)	core	douyin_account_daily	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
266	账号构成	account_mix	49	商品点击-成交转化率(次数)	core	douyin_account_daily	click_to_transaction_rate_events	商品点击-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
267	账号构成	account_mix	50	商品曝光-成交转化率(次数)	core	douyin_account_daily	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
62	自营成交	self_operated_deal	11	客单价	core	douyin_deal_daily	avg_customer_amount	客单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
391	品类构成	category_mix	9	退款金额(支付时间)	core	douyin_category_daily	refund_amount_pay_time	退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
270	账号构成	account_mix	53	商品曝光-成交转化率(人数)	core	douyin_account_daily	exposure_to_transaction_rate_users	商品曝光-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
271	账号构成	account_mix	54	千次曝光用户支付金额	core	douyin_account_daily	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
275	账号构成	account_mix	58	投放费比(店铺绑定)	core	douyin_account_daily	ad_spend_rate_shop_bound	投放费比(店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_bound) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
276	账号构成	account_mix	59	投放费比(店铺被投)	core	douyin_account_daily	ad_spend_rate_shop_promoted	投放费比(店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_promoted) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
277	账号构成	account_mix	60	投放费比(剔除退款、店铺绑定)	core	douyin_account_daily	ad_spend_rate_net_refund_shop_bound	投放费比(剔除退款、店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_bound) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
278	账号构成	account_mix	61	综合费比(店铺绑定)	core	douyin_account_daily	total_expense_rate_shop_bound	综合费比(店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
279	账号构成	account_mix	62	综合费比(店铺被投)	core	douyin_account_daily	total_expense_rate_shop_promoted	综合费比(店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
280	账号构成	account_mix	63	综合费比(剔除退款、店铺绑定)	core	douyin_account_daily	total_expense_rate_net_refund_shop_bound	综合费比(剔除退款、店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
281	账号构成	account_mix	64	综合费比(剔除退款、店铺被投)	core	douyin_account_daily	total_expense_rate_net_refund_shop_promoted	综合费比(剔除退款、店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
292	单载体构成	content_mix	11	退款率(支付时间)	core	douyin_content_daily	refund_rate_pay_time	退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
396	商品构成	product_mix	4	载体类型	core	douyin_product_daily	carrier_type	载体类型	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
397	商品构成	product_mix	5	用户支付金额	core	douyin_product_daily	user_pay_amount	用户支付金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
400	商品构成	product_mix	8	退款金额(支付时间)	core	douyin_product_daily	refund_amount_pay_time	退款金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
402	商品构成	product_mix	10	智能优惠券金额	core	douyin_product_daily	smart_coupon_amount	智能优惠券金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
403	商品构成	product_mix	11	电商平台补贴金额	core	douyin_product_daily	platform_subsidy_amount	电商平台补贴金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
404	商品构成	product_mix	12	退款后智能优惠券金额(支付时间)	core	douyin_product_daily	net_smart_coupon_amount_pay_time	退款后智能优惠券金额(支付时间)	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
405	商品构成	product_mix	13	退款后电商平台补贴金额(支付时间)	core	douyin_product_daily	net_platform_subsidy_amount_pay_time	退款后平台补贴金额（支付时间）	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
406	价格带构成	price_band_mix	1	日期	core	douyin_price_band_daily	biz_date	业务日期	DATE	业务日期	不聚合	按YYYYMMDD解析为DATE；非法日期阻止导入	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
407	价格带构成	price_band_mix	2	价格带	core	douyin_price_band_daily	price_band	价格带	VARCHAR(100)	维度字段	分组维度	按文本读取并TRIM；保留前导零；空白统一为空字符串以保证业务键稳定	number	\N	\N	t	t	V1.4	t		2026-08-07 13:54:57.932418+08
408	价格带构成	price_band_mix	3	用户支付金额	core	douyin_price_band_daily	user_pay_amount	用户支付金额	NUMERIC(20,2)	可累加金额指标	SUM	空白转NULL；去除千分位后转为数值	number	\N	\N	f	t	V1.4	t		2026-08-07 13:54:57.932418+08
294	单载体构成	content_mix	13	投放贡献成交占比	core	douyin_content_daily	ad_attributed_transaction_share	投放贡献成交占比	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_attributed_transaction_amount) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
296	单载体构成	content_mix	15	投放费比(剔除退款、店铺被投)	core	douyin_content_daily	ad_spend_rate_net_refund_shop_promoted	投放费比(剔除退款、店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_promoted) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
297	单载体构成	content_mix	16	商品曝光-点击转化率(人数)	core	douyin_content_daily	exposure_to_click_rate_users	商品曝光-点击转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_user_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
298	单载体构成	content_mix	17	商品点击-成交转化率(人数)	core	douyin_content_daily	click_to_transaction_rate_users	商品点击-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_click_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
307	单载体构成	content_mix	26	客单价	core	douyin_content_daily	avg_customer_amount	客单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
324	单载体构成	content_mix	43	1小时退款率(支付时间)	core	douyin_content_daily	one_hour_refund_rate_pay_time	1小时退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
326	单载体构成	content_mix	45	投放部分退款率(支付时间)	core	douyin_content_daily	ad_attributed_refund_rate_pay_time	投放部分退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_attributed_transaction_refund_amount_pay_time) / NULLIF(SUM(ad_attributed_transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
329	单载体构成	content_mix	48	商品曝光-点击转化率(次数)	core	douyin_content_daily	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
330	单载体构成	content_mix	49	商品点击-成交转化率(次数)	core	douyin_content_daily	click_to_transaction_rate_events	商品点击-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
331	单载体构成	content_mix	50	商品曝光-成交转化率(次数)	core	douyin_content_daily	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
334	单载体构成	content_mix	53	商品曝光-成交转化率(人数)	core	douyin_content_daily	exposure_to_transaction_rate_users	商品曝光-成交转化率(人数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_buyer_count) / NULLIF(SUM(product_exposure_user_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
241	账号构成	account_mix	24	件单价	core	douyin_account_daily	avg_item_amount	件单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
339	单载体构成	content_mix	58	投放费比(店铺绑定)	core	douyin_content_daily	ad_spend_rate_shop_bound	投放费比(店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_bound) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
340	单载体构成	content_mix	59	投放费比(店铺被投)	core	douyin_content_daily	ad_spend_rate_shop_promoted	投放费比(店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_promoted) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
341	单载体构成	content_mix	60	投放费比(剔除退款、店铺绑定)	core	douyin_content_daily	ad_spend_rate_net_refund_shop_bound	投放费比(剔除退款、店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(ad_spend_shop_bound) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
342	单载体构成	content_mix	61	综合费比(店铺绑定)	core	douyin_content_daily	total_expense_rate_shop_bound	综合费比(店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
343	单载体构成	content_mix	62	综合费比(店铺被投)	core	douyin_content_daily	total_expense_rate_shop_promoted	综合费比(店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
344	单载体构成	content_mix	63	综合费比(剔除退款、店铺绑定)	core	douyin_content_daily	total_expense_rate_net_refund_shop_bound	综合费比(剔除退款、店铺绑定)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
345	单载体构成	content_mix	64	综合费比(剔除退款、店铺被投)	core	douyin_content_daily	total_expense_rate_net_refund_shop_promoted	综合费比(剔除退款、店铺被投)	NUMERIC(18,8)	比例指标	按V1.4公式重算：(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
354	终端构成	terminal_mix	9	退款率(支付时间)	core	douyin_terminal_daily	refund_rate_pay_time	退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
357	终端构成	terminal_mix	12	商品曝光-点击转化率(次数)	core	douyin_terminal_daily	exposure_to_click_rate_events	商品曝光-点击转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
358	终端构成	terminal_mix	13	商品点击-成交转化率(次数)	core	douyin_terminal_daily	click_to_transaction_rate_events	商品点击-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
144	合作成交	partner_deal	42	件单价	core	douyin_deal_daily	avg_item_amount	件单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
380	终端构成	terminal_mix	35	1小时退款率(支付时间)	core	douyin_terminal_daily	one_hour_refund_rate_pay_time	1小时退款率(支付时间)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
381	终端构成	terminal_mix	36	商品曝光-成交转化率(次数)	core	douyin_terminal_daily	exposure_to_transaction_rate_events	商品曝光-成交转化率(次数)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
382	终端构成	terminal_mix	37	千次曝光用户支付金额	core	douyin_terminal_daily	user_pay_amount_per_1000_exposures	千次曝光用户支付金额	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已明确；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
389	品类构成	category_mix	7	成交笔单价	core	douyin_category_daily	avg_transaction_order_amount	成交笔单价	NUMERIC(20,4)	均值指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
390	品类构成	category_mix	8	商品点击-成交转化率(次数)	core	douyin_category_daily	click_to_transaction_rate_events	商品点击-成交转化率(次数)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
392	品类构成	category_mix	10	退款率(支付时间)	core	douyin_category_daily	refund_rate_pay_time	退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
398	商品构成	product_mix	6	成交笔单价	core	douyin_product_daily	avg_transaction_order_amount	成交笔单价	NUMERIC(20,4)	均值指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
399	商品构成	product_mix	7	商品点击-成交转化率(次数)	core	douyin_product_daily	click_to_transaction_rate_events	商品点击-成交转化率(次数)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
401	商品构成	product_mix	9	退款率(支付时间)	core	douyin_product_daily	refund_rate_pay_time	退款率(支付时间)	NUMERIC(18,8)	比例指标	按V1.4公式重算：SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)；禁止SUM/AVG	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
409	价格带构成	price_band_mix	4	成交笔单价	core	douyin_price_band_daily	avg_transaction_order_amount	成交笔单价	NUMERIC(20,4)	均值指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
410	价格带构成	price_band_mix	5	商品点击-成交转化率(次数)	core	douyin_price_band_daily	click_to_transaction_rate_events	商品点击-成交转化率(次数)	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
418	人群构成	audience_mix	8	复购用户复购率	core	douyin_audience_daily	repeat_user_repeat_rate	复购用户复购率	NUMERIC(18,8)	比例指标	仅保留源值；当前不可精确跨期重算；禁止SUM/AVG；详见meta.metric_formula_rule	空白转NULL；Excel单元格为数值类型时原值保留且允许大于1；仅当源值为明确带%号的文本时去除%并除以100；禁止根据数值大小自动除以100；跨期按分子分母重新计算；展示为0.00%	percent	0.00%	2	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否	2026-08-07 13:54:57.932418+08
11	成交概览	deal_overview	11	客单价	core	douyin_deal_daily	avg_customer_amount	客单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
364	终端构成	terminal_mix	19	件单价	core	douyin_terminal_daily	avg_item_amount	件单价	NUMERIC(20,4)	均值指标	按V1.4公式重算：SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)；禁止SUM/AVG	空白转NULL；跨期按对应分子分母加权重算	number	\N	\N	f	t	V1.4	t	V1.4指标公式规则已登记；规则状态=已确认；跨期可精确重算=是；允许自动采用=是	2026-08-07 13:54:57.932418+08
\.


--
-- Data for Name: metric_formula_rule; Type: TABLE DATA; Schema: meta; Owner: postgres
--

COPY meta.metric_formula_rule (metric_rule_id, target_schema, target_table, target_column_name_cn, target_column_name, metric_category, calculation_mode, formula_cn, numerator_expression, denominator_expression, multiplier, single_row_formula, period_formula_sql, zero_denominator_rule, cross_period_recalculable, auto_use_allowed, rule_status, display_format, mapping_version, notes, created_at, verification_method, verification_period, verification_result) FROM stdin;
1	core	douyin_deal_daily	客单价	avg_customer_amount	均值指标	ratio	用户支付金额 ÷ 成交人数	user_pay_amount	transaction_buyer_count	1.00000000	(user_pay_amount) / NULLIF(transaction_buyer_count, 0)	SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)	NULL	t	t	已确认	0.0000	V1.4	V1.4确认：真实6月Excel反算与源值一致；少量差异仅来自源Excel显示精度/四舍五入，不影响公式成立。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	公式成立；98.7%逐值匹配，剩余为展示舍入差异
2	core	douyin_deal_daily	退款率(支付时间)	refund_rate_pay_time	比例指标	ratio	退款金额(支付时间) ÷ 用户支付金额	refund_amount_pay_time	user_pay_amount	1.00000000	(refund_amount_pay_time) / NULLIF(user_pay_amount, 0)	SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
3	core	douyin_deal_daily	商品曝光-点击转化率(人数)	exposure_to_click_rate_users	比例指标	ratio	商品点击人数 ÷ 商品曝光人数	product_click_user_count	product_exposure_user_count	1.00000000	(product_click_user_count) / NULLIF(product_exposure_user_count, 0)	SUM(product_click_user_count) / NULLIF(SUM(product_exposure_user_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗人数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
4	core	douyin_deal_daily	商品点击-成交转化率(人数)	click_to_transaction_rate_users	比例指标	ratio	成交人数 ÷ 商品点击人数	transaction_buyer_count	product_click_user_count	1.00000000	(transaction_buyer_count) / NULLIF(product_click_user_count, 0)	SUM(transaction_buyer_count) / NULLIF(SUM(product_click_user_count), 0)	NULL	t	t	已确认	0.00%	V1.4	用户已明确确认该口径；例如0.1972展示为19.72%。	2026-08-07 16:32:59.742308+08	此前已确认	\N	保持已确认
5	core	douyin_deal_daily	商品曝光-成交转化率(人数)	exposure_to_transaction_rate_users	比例指标	ratio	成交人数 ÷ 商品曝光人数	transaction_buyer_count	product_exposure_user_count	1.00000000	(transaction_buyer_count) / NULLIF(product_exposure_user_count, 0)	SUM(transaction_buyer_count) / NULLIF(SUM(product_exposure_user_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗人数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
6	core	douyin_deal_daily	千次曝光用户支付金额	user_pay_amount_per_1000_exposures	均值指标	ratio_x1000	用户支付金额 ÷ 商品曝光次数 × 1000	user_pay_amount	product_exposure_count	1000.00000000	(user_pay_amount) / NULLIF(product_exposure_count, 0) * 1000	SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000	NULL	t	t	已明确	0.0000	V1.4	千次曝光口径，跨期必须按汇总金额/汇总曝光次数重算。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
7	core	douyin_deal_daily	商品曝光-点击转化率(次数)	exposure_to_click_rate_events	比例指标	ratio	商品点击次数 ÷ 商品曝光次数	product_click_count	product_exposure_count	1.00000000	(product_click_count) / NULLIF(product_exposure_count, 0)	SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗次数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
8	core	douyin_deal_daily	商品点击-成交转化率(次数)	click_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品点击次数	transaction_order_count	product_click_count	1.00000000	(transaction_order_count) / NULLIF(product_click_count, 0)	SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)	NULL	t	t	已明确	0.00%	V1.4	公式明确；若目标表缺成交订单数或商品点击次数，则只能保存源值，不能跨期精确重算。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
9	core	douyin_deal_daily	商品曝光-成交转化率(次数)	exposure_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品曝光次数	transaction_order_count	product_exposure_count	1.00000000	(transaction_order_count) / NULLIF(product_exposure_count, 0)	SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗次数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
10	core	douyin_deal_daily	两日内发货率	ship_within_2_days_rate	比例指标	source_only	平台源值；当前样表缺少明确分子/分母	\N	\N	1.00000000	\N	\N	NULL	f	f	待平台口径确认	0.00%	V1.4	不得AVG；在补齐两日内发货分子/应发货分母前，跨期不自动计算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持待平台口径确认
11	core	douyin_deal_daily	件单价	avg_item_amount	均值指标	ratio	用户支付金额 ÷ 成交件数	user_pay_amount	transaction_item_count	1.00000000	(user_pay_amount) / NULLIF(transaction_item_count, 0)	SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)	NULL	t	t	已确认	0.0000	V1.4	V1.4确认：真实6月Excel反算与源值一致；少量差异仅来自源Excel显示精度/四舍五入，不影响公式成立。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	公式成立；98.7%逐值匹配，剩余为展示舍入差异
12	core	douyin_deal_daily	发货前退款率(支付时间)	pre_shipment_refund_rate_pay_time	比例指标	source_only	平台源值；当前样表缺少发货前退款专用分子	\N	\N	1.00000000	\N	\N	NULL	f	f	缺基础字段	0.00%	V1.4	不得AVG；跨期暂不精确重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持缺基础字段
13	core	douyin_deal_daily	未收货退款率(支付时间)	unreceived_refund_rate_pay_time	比例指标	source_only	平台源值；当前样表缺少未收货退款专用分子	\N	\N	1.00000000	\N	\N	NULL	f	f	缺基础字段	0.00%	V1.4	不得AVG；跨期暂不精确重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持缺基础字段
14	core	douyin_deal_daily	已收货退款率(支付时间)	received_refund_rate_pay_time	比例指标	source_only	平台源值；当前样表缺少已收货退款专用分子	\N	\N	1.00000000	\N	\N	NULL	f	f	缺基础字段	0.00%	V1.4	不得AVG；跨期暂不精确重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持缺基础字段
15	core	douyin_deal_daily	已收货退货退款率(支付时间)	received_return_refund_rate_pay_time	比例指标	source_only	平台源值；当前样表缺少已收货退货退款专用分子	\N	\N	1.00000000	\N	\N	NULL	f	f	缺基础字段	0.00%	V1.4	不得AVG；跨期暂不精确重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持缺基础字段
16	core	douyin_deal_daily	1小时退款率（支付时间）	one_hour_refund_rate_pay_time	比例指标	source_only	平台源值；当前虽有1小时退款金额/订单数，但分母口径尚未确认	\N	\N	1.00000000	\N	\N	NULL	f	f	待平台口径确认	0.00%	V1.4	为避免错误选择金额口径或订单口径，确认平台定义前不自动跨期重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持待平台口径确认
17	core	douyin_carrier_daily	退款率(支付时间)	refund_rate_pay_time	比例指标	ratio	退款金额(支付时间) ÷ 用户支付金额	refund_amount_pay_time	user_pay_amount	1.00000000	(refund_amount_pay_time) / NULLIF(user_pay_amount, 0)	SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
18	core	douyin_carrier_daily	投放贡献成交占比	ad_attributed_transaction_share	比例指标	ratio	投放贡献成交金额 ÷ 成交金额	ad_attributed_transaction_amount	transaction_amount	1.00000000	(ad_attributed_transaction_amount) / NULLIF(transaction_amount, 0)	SUM(ad_attributed_transaction_amount) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
19	core	douyin_carrier_daily	投放费比(剔除退款、店铺被投)	ad_spend_rate_net_refund_shop_promoted	比例指标	ratio	投放消耗(店铺被投) ÷ 结算金额	ad_spend_shop_promoted	settlement_amount	1.00000000	(ad_spend_shop_promoted) / NULLIF(settlement_amount, 0)	SUM(ad_spend_shop_promoted) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
20	core	douyin_carrier_daily	商品曝光-点击转化率(人数)	exposure_to_click_rate_users	比例指标	ratio	商品点击人数 ÷ 商品曝光人数	product_click_user_count	product_exposure_user_count	1.00000000	(product_click_user_count) / NULLIF(product_exposure_user_count, 0)	SUM(product_click_user_count) / NULLIF(SUM(product_exposure_user_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗人数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
21	core	douyin_carrier_daily	商品点击-成交转化率(人数)	click_to_transaction_rate_users	比例指标	ratio	成交人数 ÷ 商品点击人数	transaction_buyer_count	product_click_user_count	1.00000000	(transaction_buyer_count) / NULLIF(product_click_user_count, 0)	SUM(transaction_buyer_count) / NULLIF(SUM(product_click_user_count), 0)	NULL	t	t	已确认	0.00%	V1.4	用户已明确确认该口径；例如0.1972展示为19.72%。	2026-08-07 16:32:59.742308+08	此前已确认	\N	保持已确认
22	core	douyin_carrier_daily	件单价	avg_item_amount	均值指标	ratio	用户支付金额 ÷ 成交件数	user_pay_amount	transaction_item_count	1.00000000	(user_pay_amount) / NULLIF(transaction_item_count, 0)	SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)	NULL	t	t	已确认	0.0000	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
23	core	douyin_carrier_daily	客单价	avg_customer_amount	均值指标	ratio	用户支付金额 ÷ 成交人数	user_pay_amount	transaction_buyer_count	1.00000000	(user_pay_amount) / NULLIF(transaction_buyer_count, 0)	SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)	NULL	t	t	已确认	0.0000	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
24	core	douyin_carrier_daily	1小时退款率(支付时间)	one_hour_refund_rate_pay_time	比例指标	source_only	平台源值；当前虽有1小时退款金额/订单数，但分母口径尚未确认	\N	\N	1.00000000	\N	\N	NULL	f	f	待平台口径确认	0.00%	V1.4	为避免错误选择金额口径或订单口径，确认平台定义前不自动跨期重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持待平台口径确认
25	core	douyin_carrier_daily	投放部分退款率(支付时间)	ad_attributed_refund_rate_pay_time	比例指标	ratio	投放贡献成交退款金额(支付时间) ÷ 投放贡献成交金额	ad_attributed_transaction_refund_amount_pay_time	ad_attributed_transaction_amount	1.00000000	(ad_attributed_transaction_refund_amount_pay_time) / NULLIF(ad_attributed_transaction_amount, 0)	SUM(ad_attributed_transaction_refund_amount_pay_time) / NULLIF(SUM(ad_attributed_transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
26	core	douyin_carrier_daily	商品曝光-点击转化率(次数)	exposure_to_click_rate_events	比例指标	ratio	商品点击次数 ÷ 商品曝光次数	product_click_count	product_exposure_count	1.00000000	(product_click_count) / NULLIF(product_exposure_count, 0)	SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗次数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
27	core	douyin_carrier_daily	商品点击-成交转化率(次数)	click_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品点击次数	transaction_order_count	product_click_count	1.00000000	(transaction_order_count) / NULLIF(product_click_count, 0)	SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)	NULL	t	t	已明确	0.00%	V1.4	公式明确；若目标表缺成交订单数或商品点击次数，则只能保存源值，不能跨期精确重算。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
28	core	douyin_carrier_daily	商品曝光-成交转化率(次数)	exposure_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品曝光次数	transaction_order_count	product_exposure_count	1.00000000	(transaction_order_count) / NULLIF(product_exposure_count, 0)	SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗次数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
29	core	douyin_carrier_daily	商品曝光-成交转化率(人数)	exposure_to_transaction_rate_users	比例指标	ratio	成交人数 ÷ 商品曝光人数	transaction_buyer_count	product_exposure_user_count	1.00000000	(transaction_buyer_count) / NULLIF(product_exposure_user_count, 0)	SUM(transaction_buyer_count) / NULLIF(SUM(product_exposure_user_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗人数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
30	core	douyin_carrier_daily	千次曝光用户支付金额	user_pay_amount_per_1000_exposures	均值指标	ratio_x1000	用户支付金额 ÷ 商品曝光次数 × 1000	user_pay_amount	product_exposure_count	1000.00000000	(user_pay_amount) / NULLIF(product_exposure_count, 0) * 1000	SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000	NULL	t	t	已明确	0.0000	V1.4	千次曝光口径，跨期必须按汇总金额/汇总曝光次数重算。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
31	core	douyin_carrier_daily	投放费比(店铺绑定)	ad_spend_rate_shop_bound	比例指标	ratio	投放消耗(店铺绑定) ÷ 成交金额	ad_spend_shop_bound	transaction_amount	1.00000000	(ad_spend_shop_bound) / NULLIF(transaction_amount, 0)	SUM(ad_spend_shop_bound) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
32	core	douyin_carrier_daily	投放费比(店铺被投)	ad_spend_rate_shop_promoted	比例指标	ratio	投放消耗(店铺被投) ÷ 成交金额	ad_spend_shop_promoted	transaction_amount	1.00000000	(ad_spend_shop_promoted) / NULLIF(transaction_amount, 0)	SUM(ad_spend_shop_promoted) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
33	core	douyin_carrier_daily	投放费比(剔除退款、店铺绑定)	ad_spend_rate_net_refund_shop_bound	比例指标	ratio	投放消耗(店铺绑定) ÷ 结算金额	ad_spend_shop_bound	settlement_amount	1.00000000	(ad_spend_shop_bound) / NULLIF(settlement_amount, 0)	SUM(ad_spend_shop_bound) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
34	core	douyin_carrier_daily	综合费比(店铺绑定)	total_expense_rate_shop_bound	比例指标	ratio_expr	(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 成交金额	ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement	transaction_amount	1.00000000	(ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement) / NULLIF(transaction_amount, 0)	(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
35	core	douyin_carrier_daily	综合费比(店铺被投)	total_expense_rate_shop_promoted	比例指标	ratio_expr	(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 成交金额	ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement	transaction_amount	1.00000000	(ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement) / NULLIF(transaction_amount, 0)	(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
36	core	douyin_carrier_daily	综合费比(剔除退款、店铺绑定)	total_expense_rate_net_refund_shop_bound	比例指标	ratio_expr	(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 结算金额	ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement	settlement_amount	1.00000000	(ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement) / NULLIF(settlement_amount, 0)	(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
37	core	douyin_carrier_daily	综合费比(剔除退款、店铺被投)	total_expense_rate_net_refund_shop_promoted	比例指标	ratio_expr	(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 结算金额	ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement	settlement_amount	1.00000000	(ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement) / NULLIF(settlement_amount, 0)	(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
38	core	douyin_account_daily	退款率(支付时间)	refund_rate_pay_time	比例指标	ratio	退款金额(支付时间) ÷ 用户支付金额	refund_amount_pay_time	user_pay_amount	1.00000000	(refund_amount_pay_time) / NULLIF(user_pay_amount, 0)	SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
39	core	douyin_account_daily	投放贡献成交占比	ad_attributed_transaction_share	比例指标	ratio	投放贡献成交金额 ÷ 成交金额	ad_attributed_transaction_amount	transaction_amount	1.00000000	(ad_attributed_transaction_amount) / NULLIF(transaction_amount, 0)	SUM(ad_attributed_transaction_amount) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
40	core	douyin_account_daily	投放费比(剔除退款、店铺被投)	ad_spend_rate_net_refund_shop_promoted	比例指标	ratio	投放消耗(店铺被投) ÷ 结算金额	ad_spend_shop_promoted	settlement_amount	1.00000000	(ad_spend_shop_promoted) / NULLIF(settlement_amount, 0)	SUM(ad_spend_shop_promoted) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
41	core	douyin_account_daily	商品曝光-点击转化率(人数)	exposure_to_click_rate_users	比例指标	ratio	商品点击人数 ÷ 商品曝光人数	product_click_user_count	product_exposure_user_count	1.00000000	(product_click_user_count) / NULLIF(product_exposure_user_count, 0)	SUM(product_click_user_count) / NULLIF(SUM(product_exposure_user_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗人数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
42	core	douyin_account_daily	商品点击-成交转化率(人数)	click_to_transaction_rate_users	比例指标	ratio	成交人数 ÷ 商品点击人数	transaction_buyer_count	product_click_user_count	1.00000000	(transaction_buyer_count) / NULLIF(product_click_user_count, 0)	SUM(transaction_buyer_count) / NULLIF(SUM(product_click_user_count), 0)	NULL	t	t	已确认	0.00%	V1.4	用户已明确确认该口径；例如0.1972展示为19.72%。	2026-08-07 16:32:59.742308+08	此前已确认	\N	保持已确认
43	core	douyin_account_daily	件单价	avg_item_amount	均值指标	ratio	用户支付金额 ÷ 成交件数	user_pay_amount	transaction_item_count	1.00000000	(user_pay_amount) / NULLIF(transaction_item_count, 0)	SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)	NULL	t	t	已确认	0.0000	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
44	core	douyin_account_daily	客单价	avg_customer_amount	均值指标	ratio	用户支付金额 ÷ 成交人数	user_pay_amount	transaction_buyer_count	1.00000000	(user_pay_amount) / NULLIF(transaction_buyer_count, 0)	SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)	NULL	t	t	已确认	0.0000	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
45	core	douyin_account_daily	1小时退款率(支付时间)	one_hour_refund_rate_pay_time	比例指标	source_only	平台源值；当前虽有1小时退款金额/订单数，但分母口径尚未确认	\N	\N	1.00000000	\N	\N	NULL	f	f	待平台口径确认	0.00%	V1.4	为避免错误选择金额口径或订单口径，确认平台定义前不自动跨期重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持待平台口径确认
46	core	douyin_account_daily	投放部分退款率(支付时间)	ad_attributed_refund_rate_pay_time	比例指标	ratio	投放贡献成交退款金额(支付时间) ÷ 投放贡献成交金额	ad_attributed_transaction_refund_amount_pay_time	ad_attributed_transaction_amount	1.00000000	(ad_attributed_transaction_refund_amount_pay_time) / NULLIF(ad_attributed_transaction_amount, 0)	SUM(ad_attributed_transaction_refund_amount_pay_time) / NULLIF(SUM(ad_attributed_transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
47	core	douyin_account_daily	商品曝光-点击转化率(次数)	exposure_to_click_rate_events	比例指标	ratio	商品点击次数 ÷ 商品曝光次数	product_click_count	product_exposure_count	1.00000000	(product_click_count) / NULLIF(product_exposure_count, 0)	SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗次数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
48	core	douyin_account_daily	商品点击-成交转化率(次数)	click_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品点击次数	transaction_order_count	product_click_count	1.00000000	(transaction_order_count) / NULLIF(product_click_count, 0)	SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)	NULL	t	t	已明确	0.00%	V1.4	公式明确；若目标表缺成交订单数或商品点击次数，则只能保存源值，不能跨期精确重算。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
49	core	douyin_account_daily	商品曝光-成交转化率(次数)	exposure_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品曝光次数	transaction_order_count	product_exposure_count	1.00000000	(transaction_order_count) / NULLIF(product_exposure_count, 0)	SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗次数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
50	core	douyin_account_daily	商品曝光-成交转化率(人数)	exposure_to_transaction_rate_users	比例指标	ratio	成交人数 ÷ 商品曝光人数	transaction_buyer_count	product_exposure_user_count	1.00000000	(transaction_buyer_count) / NULLIF(product_exposure_user_count, 0)	SUM(transaction_buyer_count) / NULLIF(SUM(product_exposure_user_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗人数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
51	core	douyin_account_daily	千次曝光用户支付金额	user_pay_amount_per_1000_exposures	均值指标	ratio_x1000	用户支付金额 ÷ 商品曝光次数 × 1000	user_pay_amount	product_exposure_count	1000.00000000	(user_pay_amount) / NULLIF(product_exposure_count, 0) * 1000	SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000	NULL	t	t	已明确	0.0000	V1.4	千次曝光口径，跨期必须按汇总金额/汇总曝光次数重算。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
52	core	douyin_account_daily	投放费比(店铺绑定)	ad_spend_rate_shop_bound	比例指标	ratio	投放消耗(店铺绑定) ÷ 成交金额	ad_spend_shop_bound	transaction_amount	1.00000000	(ad_spend_shop_bound) / NULLIF(transaction_amount, 0)	SUM(ad_spend_shop_bound) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
53	core	douyin_account_daily	投放费比(店铺被投)	ad_spend_rate_shop_promoted	比例指标	ratio	投放消耗(店铺被投) ÷ 成交金额	ad_spend_shop_promoted	transaction_amount	1.00000000	(ad_spend_shop_promoted) / NULLIF(transaction_amount, 0)	SUM(ad_spend_shop_promoted) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
54	core	douyin_account_daily	投放费比(剔除退款、店铺绑定)	ad_spend_rate_net_refund_shop_bound	比例指标	ratio	投放消耗(店铺绑定) ÷ 结算金额	ad_spend_shop_bound	settlement_amount	1.00000000	(ad_spend_shop_bound) / NULLIF(settlement_amount, 0)	SUM(ad_spend_shop_bound) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
55	core	douyin_account_daily	综合费比(店铺绑定)	total_expense_rate_shop_bound	比例指标	ratio_expr	(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 成交金额	ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement	transaction_amount	1.00000000	(ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement) / NULLIF(transaction_amount, 0)	(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
68	core	douyin_content_daily	商品曝光-点击转化率(次数)	exposure_to_click_rate_events	比例指标	ratio	商品点击次数 ÷ 商品曝光次数	product_click_count	product_exposure_count	1.00000000	(product_click_count) / NULLIF(product_exposure_count, 0)	SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗次数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
56	core	douyin_account_daily	综合费比(店铺被投)	total_expense_rate_shop_promoted	比例指标	ratio_expr	(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 成交金额	ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement	transaction_amount	1.00000000	(ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement) / NULLIF(transaction_amount, 0)	(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
57	core	douyin_account_daily	综合费比(剔除退款、店铺绑定)	total_expense_rate_net_refund_shop_bound	比例指标	ratio_expr	(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 结算金额	ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement	settlement_amount	1.00000000	(ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement) / NULLIF(settlement_amount, 0)	(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
58	core	douyin_account_daily	综合费比(剔除退款、店铺被投)	total_expense_rate_net_refund_shop_promoted	比例指标	ratio_expr	(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 结算金额	ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement	settlement_amount	1.00000000	(ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement) / NULLIF(settlement_amount, 0)	(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
59	core	douyin_content_daily	退款率(支付时间)	refund_rate_pay_time	比例指标	ratio	退款金额(支付时间) ÷ 用户支付金额	refund_amount_pay_time	user_pay_amount	1.00000000	(refund_amount_pay_time) / NULLIF(user_pay_amount, 0)	SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
60	core	douyin_content_daily	投放贡献成交占比	ad_attributed_transaction_share	比例指标	ratio	投放贡献成交金额 ÷ 成交金额	ad_attributed_transaction_amount	transaction_amount	1.00000000	(ad_attributed_transaction_amount) / NULLIF(transaction_amount, 0)	SUM(ad_attributed_transaction_amount) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
61	core	douyin_content_daily	投放费比(剔除退款、店铺被投)	ad_spend_rate_net_refund_shop_promoted	比例指标	ratio	投放消耗(店铺被投) ÷ 结算金额	ad_spend_shop_promoted	settlement_amount	1.00000000	(ad_spend_shop_promoted) / NULLIF(settlement_amount, 0)	SUM(ad_spend_shop_promoted) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
62	core	douyin_content_daily	商品曝光-点击转化率(人数)	exposure_to_click_rate_users	比例指标	ratio	商品点击人数 ÷ 商品曝光人数	product_click_user_count	product_exposure_user_count	1.00000000	(product_click_user_count) / NULLIF(product_exposure_user_count, 0)	SUM(product_click_user_count) / NULLIF(SUM(product_exposure_user_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗人数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
63	core	douyin_content_daily	商品点击-成交转化率(人数)	click_to_transaction_rate_users	比例指标	ratio	成交人数 ÷ 商品点击人数	transaction_buyer_count	product_click_user_count	1.00000000	(transaction_buyer_count) / NULLIF(product_click_user_count, 0)	SUM(transaction_buyer_count) / NULLIF(SUM(product_click_user_count), 0)	NULL	t	t	已确认	0.00%	V1.4	用户已明确确认该口径；例如0.1972展示为19.72%。	2026-08-07 16:32:59.742308+08	此前已确认	\N	保持已确认
64	core	douyin_content_daily	件单价	avg_item_amount	均值指标	ratio	用户支付金额 ÷ 成交件数	user_pay_amount	transaction_item_count	1.00000000	(user_pay_amount) / NULLIF(transaction_item_count, 0)	SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)	NULL	t	t	已确认	0.0000	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
65	core	douyin_content_daily	客单价	avg_customer_amount	均值指标	ratio	用户支付金额 ÷ 成交人数	user_pay_amount	transaction_buyer_count	1.00000000	(user_pay_amount) / NULLIF(transaction_buyer_count, 0)	SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)	NULL	t	t	已确认	0.0000	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
66	core	douyin_content_daily	1小时退款率(支付时间)	one_hour_refund_rate_pay_time	比例指标	source_only	平台源值；当前虽有1小时退款金额/订单数，但分母口径尚未确认	\N	\N	1.00000000	\N	\N	NULL	f	f	待平台口径确认	0.00%	V1.4	为避免错误选择金额口径或订单口径，确认平台定义前不自动跨期重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持待平台口径确认
67	core	douyin_content_daily	投放部分退款率(支付时间)	ad_attributed_refund_rate_pay_time	比例指标	ratio	投放贡献成交退款金额(支付时间) ÷ 投放贡献成交金额	ad_attributed_transaction_refund_amount_pay_time	ad_attributed_transaction_amount	1.00000000	(ad_attributed_transaction_refund_amount_pay_time) / NULLIF(ad_attributed_transaction_amount, 0)	SUM(ad_attributed_transaction_refund_amount_pay_time) / NULLIF(SUM(ad_attributed_transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
69	core	douyin_content_daily	商品点击-成交转化率(次数)	click_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品点击次数	transaction_order_count	product_click_count	1.00000000	(transaction_order_count) / NULLIF(product_click_count, 0)	SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)	NULL	t	t	已明确	0.00%	V1.4	公式明确；若目标表缺成交订单数或商品点击次数，则只能保存源值，不能跨期精确重算。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
70	core	douyin_content_daily	商品曝光-成交转化率(次数)	exposure_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品曝光次数	transaction_order_count	product_exposure_count	1.00000000	(transaction_order_count) / NULLIF(product_exposure_count, 0)	SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗次数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
71	core	douyin_content_daily	商品曝光-成交转化率(人数)	exposure_to_transaction_rate_users	比例指标	ratio	成交人数 ÷ 商品曝光人数	transaction_buyer_count	product_exposure_user_count	1.00000000	(transaction_buyer_count) / NULLIF(product_exposure_user_count, 0)	SUM(transaction_buyer_count) / NULLIF(SUM(product_exposure_user_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗人数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
72	core	douyin_content_daily	千次曝光用户支付金额	user_pay_amount_per_1000_exposures	均值指标	ratio_x1000	用户支付金额 ÷ 商品曝光次数 × 1000	user_pay_amount	product_exposure_count	1000.00000000	(user_pay_amount) / NULLIF(product_exposure_count, 0) * 1000	SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000	NULL	t	t	已明确	0.0000	V1.4	千次曝光口径，跨期必须按汇总金额/汇总曝光次数重算。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
73	core	douyin_content_daily	投放费比(店铺绑定)	ad_spend_rate_shop_bound	比例指标	ratio	投放消耗(店铺绑定) ÷ 成交金额	ad_spend_shop_bound	transaction_amount	1.00000000	(ad_spend_shop_bound) / NULLIF(transaction_amount, 0)	SUM(ad_spend_shop_bound) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
74	core	douyin_content_daily	投放费比(店铺被投)	ad_spend_rate_shop_promoted	比例指标	ratio	投放消耗(店铺被投) ÷ 成交金额	ad_spend_shop_promoted	transaction_amount	1.00000000	(ad_spend_shop_promoted) / NULLIF(transaction_amount, 0)	SUM(ad_spend_shop_promoted) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
75	core	douyin_content_daily	投放费比(剔除退款、店铺绑定)	ad_spend_rate_net_refund_shop_bound	比例指标	ratio	投放消耗(店铺绑定) ÷ 结算金额	ad_spend_shop_bound	settlement_amount	1.00000000	(ad_spend_shop_bound) / NULLIF(settlement_amount, 0)	SUM(ad_spend_shop_bound) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
76	core	douyin_content_daily	综合费比(店铺绑定)	total_expense_rate_shop_bound	比例指标	ratio_expr	(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 成交金额	ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement	transaction_amount	1.00000000	(ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement) / NULLIF(transaction_amount, 0)	(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
77	core	douyin_content_daily	综合费比(店铺被投)	total_expense_rate_shop_promoted	比例指标	ratio_expr	(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 成交金额	ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement	transaction_amount	1.00000000	(ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement) / NULLIF(transaction_amount, 0)	(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(transaction_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
78	core	douyin_content_daily	综合费比(剔除退款、店铺绑定)	total_expense_rate_net_refund_shop_bound	比例指标	ratio_expr	(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 结算金额	ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement	settlement_amount	1.00000000	(ad_spend_shop_bound + platform_commission_settlement + creator_commission_settlement) / NULLIF(settlement_amount, 0)	(COALESCE(SUM(ad_spend_shop_bound),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
79	core	douyin_content_daily	综合费比(剔除退款、店铺被投)	total_expense_rate_net_refund_shop_promoted	比例指标	ratio_expr	(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 结算金额	ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement	settlement_amount	1.00000000	(ad_spend_shop_promoted + platform_commission_settlement + creator_commission_settlement) / NULLIF(settlement_amount, 0)	(COALESCE(SUM(ad_spend_shop_promoted),0) + COALESCE(SUM(platform_commission_settlement),0) + COALESCE(SUM(creator_commission_settlement),0)) / NULLIF(SUM(settlement_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4修正：真实6月Excel全量反算确认，“剔除退款”口径分母为结算金额，不是净成交金额；载体构成、账号构成、单载体构成对应规则均100%匹配。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	修正后100%匹配；分母=结算金额
80	core	douyin_terminal_daily	退款率(支付时间)	refund_rate_pay_time	比例指标	ratio	退款金额(支付时间) ÷ 用户支付金额	refund_amount_pay_time	user_pay_amount	1.00000000	(refund_amount_pay_time) / NULLIF(user_pay_amount, 0)	SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
81	core	douyin_terminal_daily	商品曝光-点击转化率(次数)	exposure_to_click_rate_events	比例指标	ratio	商品点击次数 ÷ 商品曝光次数	product_click_count	product_exposure_count	1.00000000	(product_click_count) / NULLIF(product_exposure_count, 0)	SUM(product_click_count) / NULLIF(SUM(product_exposure_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗次数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
82	core	douyin_terminal_daily	商品点击-成交转化率(次数)	click_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品点击次数	transaction_order_count	product_click_count	1.00000000	(transaction_order_count) / NULLIF(product_click_count, 0)	SUM(transaction_order_count) / NULLIF(SUM(product_click_count), 0)	NULL	t	t	已明确	0.00%	V1.4	公式明确；若目标表缺成交订单数或商品点击次数，则只能保存源值，不能跨期精确重算。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
83	core	douyin_terminal_daily	件单价	avg_item_amount	均值指标	ratio	用户支付金额 ÷ 成交件数	user_pay_amount	transaction_item_count	1.00000000	(user_pay_amount) / NULLIF(transaction_item_count, 0)	SUM(user_pay_amount) / NULLIF(SUM(transaction_item_count), 0)	NULL	t	t	已确认	0.0000	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
84	core	douyin_terminal_daily	1小时退款率(支付时间)	one_hour_refund_rate_pay_time	比例指标	source_only	平台源值；当前虽有1小时退款金额/订单数，但分母口径尚未确认	\N	\N	1.00000000	\N	\N	NULL	f	f	待平台口径确认	0.00%	V1.4	为避免错误选择金额口径或订单口径，确认平台定义前不自动跨期重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持待平台口径确认
85	core	douyin_terminal_daily	商品曝光-成交转化率(次数)	exposure_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品曝光次数	transaction_order_count	product_exposure_count	1.00000000	(transaction_order_count) / NULLIF(product_exposure_count, 0)	SUM(transaction_order_count) / NULLIF(SUM(product_exposure_count), 0)	NULL	t	t	已明确	0.00%	V1.4	漏斗次数口径。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
86	core	douyin_terminal_daily	千次曝光用户支付金额	user_pay_amount_per_1000_exposures	均值指标	ratio_x1000	用户支付金额 ÷ 商品曝光次数 × 1000	user_pay_amount	product_exposure_count	1000.00000000	(user_pay_amount) / NULLIF(product_exposure_count, 0) * 1000	SUM(user_pay_amount) / NULLIF(SUM(product_exposure_count), 0) * 1000	NULL	t	t	已明确	0.0000	V1.4	千次曝光口径，跨期必须按汇总金额/汇总曝光次数重算。	2026-08-07 16:32:59.742308+08	业务公式已明确	\N	保持已明确
87	core	douyin_category_daily	成交笔单价	avg_transaction_order_amount	均值指标	ratio	用户支付金额 ÷ 成交订单数	user_pay_amount	transaction_order_count	1.00000000	\N	\N	NULL	f	f	缺基础字段	0.0000	V1.4	公式本身明确，但部分正式表没有成交订单数字段，因此这些表不能跨期精确重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持缺基础字段
88	core	douyin_category_daily	商品点击-成交转化率(次数)	click_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品点击次数	transaction_order_count	product_click_count	1.00000000	\N	\N	NULL	f	f	缺基础字段	0.00%	V1.4	公式明确；若目标表缺成交订单数或商品点击次数，则只能保存源值，不能跨期精确重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持缺基础字段
89	core	douyin_category_daily	退款率(支付时间)	refund_rate_pay_time	比例指标	ratio	退款金额(支付时间) ÷ 用户支付金额	refund_amount_pay_time	user_pay_amount	1.00000000	(refund_amount_pay_time) / NULLIF(user_pay_amount, 0)	SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
90	core	douyin_product_daily	成交笔单价	avg_transaction_order_amount	均值指标	ratio	用户支付金额 ÷ 成交订单数	user_pay_amount	transaction_order_count	1.00000000	\N	\N	NULL	f	f	缺基础字段	0.0000	V1.4	公式本身明确，但部分正式表没有成交订单数字段，因此这些表不能跨期精确重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持缺基础字段
91	core	douyin_product_daily	商品点击-成交转化率(次数)	click_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品点击次数	transaction_order_count	product_click_count	1.00000000	\N	\N	NULL	f	f	缺基础字段	0.00%	V1.4	公式明确；若目标表缺成交订单数或商品点击次数，则只能保存源值，不能跨期精确重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持缺基础字段
92	core	douyin_product_daily	退款率(支付时间)	refund_rate_pay_time	比例指标	ratio	退款金额(支付时间) ÷ 用户支付金额	refund_amount_pay_time	user_pay_amount	1.00000000	(refund_amount_pay_time) / NULLIF(user_pay_amount, 0)	SUM(refund_amount_pay_time) / NULLIF(SUM(user_pay_amount), 0)	NULL	t	t	已确认	0.00%	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
93	core	douyin_price_band_daily	成交笔单价	avg_transaction_order_amount	均值指标	ratio	用户支付金额 ÷ 成交订单数	user_pay_amount	transaction_order_count	1.00000000	\N	\N	NULL	f	f	缺基础字段	0.0000	V1.4	公式本身明确，但部分正式表没有成交订单数字段，因此这些表不能跨期精确重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持缺基础字段
94	core	douyin_price_band_daily	商品点击-成交转化率(次数)	click_to_transaction_rate_events	比例指标	ratio	成交订单数 ÷ 商品点击次数	transaction_order_count	product_click_count	1.00000000	\N	\N	NULL	f	f	缺基础字段	0.00%	V1.4	公式明确；若目标表缺成交订单数或商品点击次数，则只能保存源值，不能跨期精确重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持缺基础字段
95	core	douyin_audience_daily	客单价	avg_customer_amount	均值指标	ratio	用户支付金额 ÷ 成交人数	user_pay_amount	transaction_buyer_count	1.00000000	(user_pay_amount) / NULLIF(transaction_buyer_count, 0)	SUM(user_pay_amount) / NULLIF(SUM(transaction_buyer_count), 0)	NULL	t	t	已确认	0.0000	V1.4	V1.4确认：使用真实2026年6月抖音电商罗盘Excel逐行反算，公式与源指标值核对通过。	2026-08-07 16:32:59.742308+08	真实6月Excel逐行反算核对	2026-06-01～2026-06-30	100%匹配
96	core	douyin_audience_daily	复购用户复购率	repeat_user_repeat_rate	比例指标	source_only	平台源值；当前样表没有复购率专用分子/分母	\N	\N	1.00000000	\N	\N	NULL	f	f	缺基础字段	0.00%	V1.4	不得AVG；跨期暂不精确重算。	2026-08-07 16:32:59.742308+08	本版不处理	\N	保持缺基础字段
\.


--
-- Data for Name: shop; Type: TABLE DATA; Schema: meta; Owner: postgres
--

COPY meta.shop (shop_id, platform_code, shop_code, shop_name, platform_shop_id, enabled, created_at) FROM stdin;
1	douyin	DY_DANDONG_OFFICIAL	弹动官方旗舰店	\N	t	2026-08-07 13:46:19.195357+08
\.


--
-- Name: database_object_dictionary_dictionary_id_seq; Type: SEQUENCE SET; Schema: meta; Owner: postgres
--

SELECT pg_catalog.setval('meta.database_object_dictionary_dictionary_id_seq', 976, true);


--
-- Name: field_mapping_mapping_id_seq; Type: SEQUENCE SET; Schema: meta; Owner: postgres
--

SELECT pg_catalog.setval('meta.field_mapping_mapping_id_seq', 1672, true);


--
-- Name: metric_formula_rule_metric_rule_id_seq; Type: SEQUENCE SET; Schema: meta; Owner: postgres
--

SELECT pg_catalog.setval('meta.metric_formula_rule_metric_rule_id_seq', 192, true);


--
-- Name: shop_shop_id_seq; Type: SEQUENCE SET; Schema: meta; Owner: postgres
--

SELECT pg_catalog.setval('meta.shop_shop_id_seq', 1, true);


--
-- Name: database_object_dictionary database_object_dictionary_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.database_object_dictionary
    ADD CONSTRAINT database_object_dictionary_pkey PRIMARY KEY (dictionary_id);


--
-- Name: field_mapping field_mapping_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping
    ADD CONSTRAINT field_mapping_pkey PRIMARY KEY (mapping_id);


--
-- Name: metric_formula_rule metric_formula_rule_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.metric_formula_rule
    ADD CONSTRAINT metric_formula_rule_pkey PRIMARY KEY (metric_rule_id);


--
-- Name: shop shop_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.shop
    ADD CONSTRAINT shop_pkey PRIMARY KEY (shop_id);


--
-- Name: database_object_dictionary uk_dict_obj_col; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.database_object_dictionary
    ADD CONSTRAINT uk_dict_obj_col UNIQUE (schema_name, object_name, column_name);


--
-- Name: field_mapping uk_field_mapping_sheet_column; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping
    ADD CONSTRAINT uk_field_mapping_sheet_column UNIQUE (source_sheet_name, source_column_name);


--
-- Name: field_mapping uk_field_mapping_sheet_order; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping
    ADD CONSTRAINT uk_field_mapping_sheet_order UNIQUE (source_sheet_name, source_column_order);


--
-- Name: metric_formula_rule uk_metric_formula_rule; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.metric_formula_rule
    ADD CONSTRAINT uk_metric_formula_rule UNIQUE (target_schema, target_table, target_column_name);


--
-- Name: shop uk_shop_code; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.shop
    ADD CONSTRAINT uk_shop_code UNIQUE (platform_code, shop_code);


--
-- Name: field_mapping fk_field_mapping_sheet; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping
    ADD CONSTRAINT fk_field_mapping_sheet FOREIGN KEY (source_sheet_name) REFERENCES meta.source_sheet_mapping(source_sheet_name);


--
-- Name: TABLE shop; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.shop TO ecommerce_importer;
GRANT SELECT ON TABLE meta.shop TO agent_readonly;


--
-- Name: TABLE metric_formula_rule; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.metric_formula_rule TO ecommerce_importer;


--
-- Name: TABLE database_object_dictionary; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.database_object_dictionary TO ecommerce_importer;


--
-- Name: TABLE field_mapping; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.field_mapping TO ecommerce_importer;


--
-- PostgreSQL database dump complete
--

