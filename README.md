# Olist E-Commerce Analytics | SQL, Excel & Power BI

## Project Overview

An end-to-end e-commerce analytics project using the Olist Brazilian E-Commerce Public Dataset to investigate sales performance, customer retention, delivery reliability, product-category performance, and customer satisfaction.

The goal was to move beyond descriptive reporting by validating business metrics, identifying meaningful patterns, and translating analytical findings into evidence-based recommendations.

## Business Questions

- How are sales and order activity distributed across product categories?
- How does delivery performance relate to customer satisfaction?
- What does repeat purchasing reveal about customer retention?
- What patterns in written reviews may indicate customer-experience issues?
- Which areas warrant further investigation to improve operational performance?

## Tools & Technologies

- **SQL — MySQL / MySQL Workbench:** Data validation, joins, aggregations, CTEs, KPI calculations, and business analysis.
- **Microsoft Excel:** Data inspection, reconciliation, supporting analysis, and analytical workbooks.
- **Power BI:** Interactive dashboards, KPI reporting, and business-focused visualizations.
- **GitHub & Markdown:** Version-controlled project assets and technical documentation.

## Analytical Workflow

1. **Data understanding and quality checks** — Reviewed source tables, record counts, relationships, data quality, and analytical grain.
2. **Data modeling and validation** — Documented table relationships and checked metric consistency across relevant datasets.
3. **SQL analysis** — Investigated sales, customer behavior, delivery performance, product categories, and review patterns.
4. **Excel analysis** — Conducted supporting analyses and reconciliations across business questions.
5. **Power BI reporting** — Developed an interactive report to communicate executive KPIs and product-performance patterns.
6. **Business interpretation** — Connected findings to practical investigation priorities while documenting limitations and assumptions.

## Executive Dashboard KPIs

| KPI | Dashboard Value | Format |
|---|---:|---|
| Total Sales | 13.59M | Currency |
| Total Orders | 99K | Whole number |
| Average Order Value (AOV) | 136.68 | Currency |
| Unique Customers | 96K | Whole number |
| Repeat Customers | 3K | Whole number |
| Repeat Customer Rate | 3.1% | Percentage |
| On-Time Delivery Rate | 93.23% | Percentage |
| Average Review Score | 4.09 | Decimal number (2 decimal places) |

*Values are presented at the precision displayed on the dashboard. Currency values use the report's configured currency format.*

## Power BI Report

The report contains two pages:

- **Executive Overview** — Consolidated performance KPIs for a high-level view of marketplace activity.
- **Sales & Product Performance** — Sales distribution and product-category performance.

## Key Findings

### Customer Retention

- Analyzed **96,096 unique customers**; **2,997** met the project's repeat-customer definition, representing approximately **3.12%**.
- In the 180-day cohort analysis, **2,098 of 68,940 eligible customers** placed repeat orders, a rate of approximately **3.04%**.
- **897 repeat customers** placed their second order on the same calendar day as their first.

**Business implication:** Repeat purchasing warrants further investigation through customer segmentation, repeat-purchase timing, and retention analysis.

### Delivery Performance & Customer Satisfaction

| Delivery Group | Average Review Score |
|---|---:|
| On time or early | 4.29 |
| 1–7 days late | 2.72 |
| 8–30 days late | 1.65 |
| More than 30 days late | 2.06 |

The group delivered more than 30 days late contained **329 records**, so its average should be interpreted cautiously.

**Business implication:** Investigating late-delivery drivers and monitoring delivery outcomes alongside customer feedback may help identify operational improvement opportunities.

The observed relationship does not establish that delivery delays alone caused lower review scores.

### Written Review Analysis

- Analyzed **42,697 written reviews**.
- Flagged **6,203 reviews**, approximately **14.53%**, for potential customer-experience issues using keyword-based rules.
- The issue-flag rate was **39.41%** among low-score reviews versus **4.50%** among high-score reviews.
- Nonreceipt-related keywords appeared in **23.39%** of low-score written reviews compared with **0.50%** of high-score written reviews.

**Business implication:** Review signals can help prioritize further investigation. Keyword flags are exploratory indicators, not definitive complaint classifications, and may produce false positives.

### Product-Category Performance

- **Health & Beauty** (`beleza_saude`) generated **R$1,258,681.34** in item sales.
- **Watches & Gifts** (`relogios_presentes`) generated **R$1,205,005.68** in item sales.
- **Bed, Bath & Table** (`cama_mesa_banho`) recorded **9,417 orders**.
- The five leading classified categories represented approximately **40.27%** of classified-category sales.

**Business implication:** Evaluate categories using both sales value and order volume. Cost and margin data would be needed to support profitability recommendations.

## Business Recommendations

1. **Delivery performance:** Investigate late-delivery drivers and monitor delivery outcomes alongside customer feedback.
2. **Customer retention:** Examine repeat-purchase behavior and customer segments to identify potential retention opportunities.
3. **Product performance:** Compare category sales and order volume, then incorporate cost and margin data before making profitability recommendations.

These are investigation priorities supported by observed patterns, not claims that proposed interventions have already improved business outcomes.

## Data Quality & Limitations

- Source tables have different grains, including orders, order items, payments, reviews, and customers. Metrics must be interpreted using their defined populations.
- Sales based on item prices exclude freight unless explicitly stated otherwise.
- Sales and payment totals may differ because they represent different business measures and require appropriate reconciliation.
- Delivery calculations depend on timestamp and date definitions; comparisons require consistent definitions.
- Same-day second orders may represent separate or parallel purchases and do not automatically indicate long-term loyalty.
- Small cohorts can produce unstable rates and averages.
- Keyword-based review flags are exploratory and may misclassify comments.
- Observational analysis identifies patterns and associations; it does not establish causation.

## Project Deliverables

### SQL Analysis
- [SQL folder guide](SQL/README.md)
- [Data import and cleanup](SQL/01_phase1_import_and_cleanup.sql)
- [Relationship checks](SQL/02_phase1_relationship_checks.sql)
- [Data quality checks](SQL/01_phase1_data_quality_checks.sql)
- [Data modeling](SQL/modelling.sql)
- [Business analysis queries](SQL/business_analysis.sql)

### Excel Business Analysis
- [Excel analysis guide](Excel%20Analysis/README.md)
- [Delivery performance](Excel%20Analysis/Mission_4A_Delivery_Performance.xlsx)
- [Monthly order trends](Excel%20Analysis/Mission_4B_Monthly_Order_Trends.xlsx)
- [Product-category performance](Excel%20Analysis/Mission_4C_Product_Category_Performance%20.xlsx)
- [Customer analysis](Excel%20Analysis/Mission_4D_Customer_Analysis.xlsx)
- [Customer reviews](Excel%20Analysis/Mission_4E_Customer_Reviews.xlsx)
- [Payment behavior](Excel%20Analysis/Mission_4F_Payment_Behavior_Analysis.xlsx)
- [Individual seller performance](Excel%20Analysis/Mission_4G_Individual_Seller_Performance.xlsx)

### Power BI
- [Power BI folder guide](Power%20BI/README.md)
- [Executive Overview screenshot](Power%20BI/Olist_Executive_Overview.png)
- [Sales & Product Performance screenshot](Power%20BI/Olist_Sales_Product_Performance.png)
- [Dashboard walkthrough video](Power%20BI/Olist_Dashboard_Walkthrough.mp4)

The Power BI PBIX file is not included in this repository. The screenshots and walkthrough video provide a preview of the report.

### Documentation
- [Business analysis findings](business_analysis_findings.md)
- [Data model documentation](data_model_documentation.md)
- [KPI definitions](kpi_definitions.md)
- [Phase 1 completion report](phase1_completion_report.txt)
- [Phase 1 table inventory](phase1_table_inventory.txt)
- [Phase 1 data dictionary](phase1_data_dictionary.csv)

### Raw Data
- [Raw Data README and dataset download instructions](Raw%20Data/README.md)

The source CSV files are not currently stored in this repository; use the Raw Data README for the dataset source and setup instructions.

## Outcome

This project demonstrates an end-to-end analytics workflow—from understanding source data and validating metrics to conducting SQL and Excel analysis, developing a Power BI report, and interpreting results in a business context.
Its emphasis is on transparent metric definitions, data quality, defensible conclusions, and actionable next steps rather than dashboard creation alone.

Its emphasis is on **transparent metric definitions, data quality, defensible conclusions, and actionable next steps** rather than dashboard creation alone.
