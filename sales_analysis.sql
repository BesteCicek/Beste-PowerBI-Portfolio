
-- ===============================
-- PEOPLE TABLOSU OLUŞTURMA
-- ===============================
-- Bölge ve o bölgeden sorumlu kişileri tutar
CREATE TABLE people (
    person VARCHAR(100),
    region VARCHAR(50)
);

-- ===============================
-- RETURNS TABLOSUNU TEXT OLARAK OLUŞTURMA
-- ===============================
-- CSV import sırasında hata almamak için tüm alanlar TEXT tanımlanır
CREATE TABLE returns(
	returned TEXT,
	order_id TEXT
);

-- ===============================
-- ORDERS TABLOSUNU TEXT OLARAK OLUŞTURMA
-- ===============================
-- CSV import sırasında hata almamak için tüm alanlar TEXT tanımlanır
CREATE TABLE orders (
    row_id TEXT,
    order_id TEXT,
    order_date TEXT,
    ship_date TEXT,
    ship_mode TEXT,
    customer_id TEXT,
    customer_name TEXT,
    segment TEXT,
    country TEXT,
    city TEXT,
    state TEXT,
    postal_code TEXT,
    region TEXT,
    product_id TEXT,
    category TEXT,
    sub_category TEXT,
    product_name TEXT,
    sales TEXT,
    quantity TEXT,
    discount TEXT,
    profit TEXT
);

-- ===============================
-- RETURNS TABLOSUNDA TEKRAR KONTROLÜ
-- ===============================
-- Aynı order_id birden fazla kez iade edilmiş mi kontrol eder
SELECT order_id, COUNT(*)
FROM returns
GROUP BY order_id
HAVING COUNT(*) > 1;

-- ===============================
-- PEOPLE TABLOSUNDA BÖLGE TEKRAR KONTROLÜ
-- ===============================
-- Aynı bölgeye birden fazla kişi atanmış mı kontrol eder
SELECT region, COUNT(*)
FROM people
GROUP BY region
HAVING COUNT(*) > 1;

-- ===============================
-- ORDERS TABLOSUNDA TOPLAM SATIR SAYISI
-- ===============================
-- Import işleminin başarılı olup olmadığını kontrol etmek için
SELECT COUNT(*) AS total_rows FROM orders;

-- ===============================
-- TARİH KOLONLARI EKLEME
-- ===============================
-- TEXT tarih alanlarını DATE formatına çevirmek için yeni kolonlar eklenir
ALTER TABLE orders
ADD COLUMN order_date_dt DATE,
ADD COLUMN ship_date_dt DATE;

-- Tarih formatlarını kontrol etmek için örnek veri
SELECT order_date, ship_date FROM orders LIMIT 5;

-- TEXT formatındaki tarihleri DATE formatına dönüştürür
UPDATE orders SET order_date_dt = TO_DATE(order_date,'DD.MM.YYYY'),
ship_date_dt=TO_DATE(ship_date, 'DD.MM.YYYY');

-- ===============================
-- SAYISAL KOLONLARI EKLEME
-- ===============================
-- Analizlerde kullanılacak numeric alanlar oluşturulur
ALTER TABLE orders
ADD COLUMN sales_num NUMERIC,
ADD COLUMN quantity_num INTEGER,
ADD COLUMN discount_num NUMERIC,
ADD COLUMN profit_num NUMERIC;

-- Virgül / nokta farklılıklarını gidererek sayısal dönüşüm yapar
UPDATE orders
SET
    sales_num    = REPLACE(sales, ',', '.')::NUMERIC,
    quantity_num = quantity::INTEGER,
    discount_num = REPLACE(discount, ',', '.')::NUMERIC,
    profit_num   = REPLACE(profit, ',', '.')::NUMERIC;

-- ===============================
-- NULL KONTROLÜ
-- ===============================
-- Dönüşüm sonrası hatalı veya eksik veri var mı kontrol eder
SELECT
    COUNT(*) FILTER (WHERE sales_num IS NULL)    AS sales_null,
    COUNT(*) FILTER (WHERE profit_num IS NULL)   AS profit_null,
    COUNT(*) FILTER (WHERE order_date_dt IS NULL) AS date_null
FROM orders;

-- ===============================
-- ORDERS + RETURNS JOIN
-- ===============================
-- Siparişlerin iade bilgisiyle birlikte listelenmesi
SELECT
    o.order_id,
    o.sales_num,
    o.profit_num,
    r.returned
FROM orders o
LEFT JOIN returns r
    ON o.order_id = r.order_id
LIMIT 10;

-- ===============================
-- ORDERS + PEOPLE JOIN
-- ===============================
-- Siparişlerin bölge yöneticisiyle birlikte listelenmesi
SELECT
    o.order_id,
    o.region,
    p.person AS region_manager
FROM orders o
LEFT JOIN people p
    ON o.region = p.region
LIMIT 10;

-- ===============================
-- TOPLAM SATIŞ VE TOPLAM KÂR
-- ===============================
-- Dashboard KPI kartları için
SELECT
    SUM(sales_num)  AS total_sales,
    SUM(profit_num) AS total_profit
FROM orders;


-- ===============================
-- KÂR MARJI HESABI
-- ===============================
-- Genel kârlılık yüzdesi
SELECT
    ROUND(SUM(profit_num) / SUM(sales_num) * 100, 2) AS profit_margin_pct
FROM orders;

-- ===============================
-- KATEGORİ BAZINDA TOPLAM KÂR
-- ===============================
-- En kârlı ürün kategorilerini analiz eder
SELECT
    category,
    ROUND(SUM(profit_num), 2) AS total_profit
FROM orders
GROUP BY category
ORDER BY total_profit DESC;

-- ===============================
-- İADE ORANI HESABI
-- ===============================
-- Toplam siparişler içindeki iade yüzdesini hesaplar
SELECT
    ROUND(
        COUNT(r.order_id)::NUMERIC
        / COUNT(o.order_id) * 100, 2
    ) AS return_rate_pct
FROM orders o
LEFT JOIN returns r
    ON o.order_id = r.order_id;

-- ===============================
-- POWER BI İÇİN ANA VIEW
-- ===============================
-- Temizlenmiş, birleştirilmiş ve analiz-ready veri kaynağı
CREATE VIEW vw_sales_analysis AS
SELECT
    o.order_id,
    o.order_date_dt,
    o.ship_date_dt,
    o.region,
    o.category,
    o.sub_category,
    o.sales_num,
    o.profit_num,
    o.quantity_num,
    o.discount_num,
    CASE
        WHEN r.order_id IS NOT NULL THEN 'Returned'
        ELSE 'Not Returned'
    END AS return_status,
    p.person AS region_manager
FROM orders o
LEFT JOIN returns r
    ON o.order_id = r.order_id
LEFT JOIN people p
    ON o.region = p.region;

-- ===============================
-- AYLIK SATIŞ VE KÂR ANALİZİ
-- ===============================
-- Sipariş tarihine göre ay bazında toplam satış ve kâr hesaplar
-- Trend ve mevsimsellik analizleri için kullanılır

SELECT
    DATE_TRUNC('month', order_date_dt) AS month,
    SUM(sales_num)  AS monthly_sales,
    SUM(profit_num) AS monthly_profit
FROM orders
GROUP BY month
ORDER BY month;

-- ===============================
-- KATEGORİ BAZINDA KÂR SIRALAMASI
-- ===============================
-- Window function (RANK) kullanılarak kategoriler kâra göre sıralanır
-- En kârlı kategorinin belirlenmesi için kullanılır

SELECT
    category,
    SUM(profit_num) AS total_profit,
    RANK() OVER (ORDER BY SUM(profit_num) DESC) AS profit_rank
FROM orders
GROUP BY category;


-- ===============================
-- POWER BI İÇİN AYLIK SATIŞ VIEW'I
-- ===============================
-- Power BI raporlarında kullanılmak üzere
-- ay ve kategori bazında özet satış ve kâr verisi sunar

CREATE VIEW vw_sales_monthly AS
SELECT
    DATE_TRUNC('month', order_date_dt) AS month,
    category,
    SUM(sales_num)  AS sales,
    SUM(profit_num) AS profit
FROM orders
GROUP BY month, category;
