\# Olist E-Commerce Analytics — Business Analysis Findings



\## 1. Purpose



This document summarizes the business questions, analytical methods, recorded findings, and limitations documented in `SQL/business\_analysis.sql`.



The analysis investigates order and payment trends, payment reconciliation, delivery performance, customer purchasing behavior, customer reviews, product categories, and seller performance.



The purpose is to translate transactional data into interpretable business findings while preserving metric definitions, data-quality considerations, and the limitations of descriptive analysis.



\## 2. Analysis Environment



\- \*\*Database:\*\* `olist\_analytics`

\- \*\*Primary analysis script:\*\* `SQL/business\_analysis.sql`

\- \*\*Supporting analysis:\*\* Excel mission workbooks and Power BI reporting

\- \*\*Source dataset:\*\* Brazilian Olist E-Commerce Public Dataset



The SQL script contains analytical queries, validation checks, reconciliation analyses, and export operations. The findings below reflect the results recorded in the project analysis.



\## 3. Business Questions



The analysis addresses the following questions:



1\. How do order volumes and order statuses change over time?

2\. How do recorded payment values compare with item and freight totals?

3\. How does delivery timeliness vary by month and geography?

4\. How does delivery performance relate to review scores and written comments?

5\. How frequently do customers place repeat orders, and how long does a second purchase take?

6\. Which product categories contribute most to item sales?

7\. How do payment methods and installments vary?

8\. How does seller performance differ across sellers and delivery outcomes?



\## 4. Orders and Revenue Trends



\### 4.1 Monthly order performance



The analysis calculates monthly order totals, delivered-order counts, canceled-order counts, and delivered percentages.



The intended grain is one row per order month. Month-over-month comparisons use the SQL `LAG` function to calculate order changes and percentage growth.



These measures help identify changes in order volume and delivery outcomes over time.



\### 4.2 Monthly payment value and average payment value



Payment records are aggregated at the order level before the monthly analysis. The documented analysis joins these results to non-canceled orders and calculates eligible order counts, total recorded payment value, and average payment value per eligible order.



\*\*Interpretation:\*\* Payment value is not automatically equivalent to product revenue. The population, order status, payment-record coverage, and inclusion of freight must be considered before comparing metrics.



\### 4.3 Payment coverage and reconciliation



The analysis checks payment-record coverage by order status and investigates orders with and without payment records.



Order-level reconciliation compares recorded payments against order item and freight totals. Differences are summarized by reconciliation rate, net difference, absolute difference, order status, payment type, and discrepancy magnitude.



Documented discrepancy bands include:



\- Under R$1

\- R$1–R$10

\- R$10–R$50

\- R$50 or more



The analysis also investigates delivered orders with large differences and examines cases where recorded payments exceed or fall below the comparison total.



\*\*Interpretation:\*\* Reconciliation differences should be investigated at the appropriate grain. An aggregate total can appear consistent even when individual orders contain discrepancies.



\## 5. Delivery Performance



\### 5.1 Delivery timeliness



The SQL investigates on-time versus late deliveries, monthly late-delivery rates, delay severity, order size, and geographic patterns.



Delay-severity bands include:



\- 1–7 days late

\- 8–30 days late

\- More than 30 days late



The project contains timestamp-based and calendar-day delivery calculations. These definitions can produce different results, so the primary dashboard metric must use one explicitly documented definition consistently.



The final published on-time count should be confirmed against the Power BI measure before it is reported as a definitive KPI.



\### 5.2 Geographic analysis



Delivery performance is analyzed by customer state and seller state.



The seller-state analysis excludes multi-state-seller orders from its state-level comparison. The SQL also documents coverage checks and analyses of late-order volume and severe delays.



Geographic comparisons use a minimum-order threshold of 100 orders, as documented in the analysis.



\*\*Interpretation:\*\* State-level rates should be read alongside their order volumes and coverage. Excluded multi-state orders mean the seller-state analysis does not represent every order.



\## 6. Customer Purchasing Behavior



\### 6.1 Customer frequency



The customer analysis distinguishes one-time and repeat purchasing, examines order-frequency distributions, and compares payment value and average order value across purchasing-frequency groups.



The documented Excel analysis covers \*\*96,096 unique customers\*\*.



Recorded customer-frequency distribution:



| Purchase frequency | Percentage of customers |

|---|---:|

| One order | 96.88% |

| Two orders | 2.86% |

| Three orders | 0.21% |

| Four or more orders | 0.05% |



The percentages are rounded.



\### 6.2 Repeat purchasing



The documented analysis identifies \*\*2,997 repeat customers\*\*, approximately \*\*3.12%\*\* of the 96,096-customer population.



Among those repeat customers, \*\*897 (29.93%)\*\* placed their second order on the same calendar day as their first.



Same-day second orders may represent parallel purchases rather than meaningful long-term retention. The original repeat-customer metric is retained, but it should not be interpreted as a direct measure of sustained loyalty.



\### 6.3 Time to second purchase



The second-purchase analysis records customer identifiers, first- and second-purchase timestamps, and the number of calendar days between the purchases.



The documented workbook reports:



\- \*\*2,997\*\* repeat customers.

\- An average gap of \*\*80.35 days\*\*.

\- Observed gaps ranging from the same day to 609 days.



The purchase-gap distribution is:



| Gap between first and second purchase | Customers | Share of repeat customers |

|---|---:|---:|

| Same day | 897 | 29.93% |

| 1–30 days | 636 | 21.22% |

| 31–60 days | 323 | 10.78% |

| 61–90 days | 203 | 6.77% |

| 91–180 days | 428 | 14.28% |

| More than 180 days | 510 | 17.02% |

| \*\*Total\*\* | \*\*2,997\*\* | \*\*100.00%\*\* |



The gap uses calendar-day differences. Same-day purchases count as zero days.



\### 6.4 180-day cohort analysis



The cohort analysis applies an eligibility rule: a customer's first purchase must occur on or before the maximum purchase date minus 180 days.



The recorded validation totals are:



\- \*\*68,940 eligible customers\*\*

\- \*\*2,098 repeaters\*\*

\- \*\*3.04% repeat rate\*\*



The workbook includes 19 monthly cohorts from September 2016 through April 2018.



Cohort rates should be interpreted alongside cohort sizes. The December 2016 cohort contains one eligible customer and a 100% repeat rate; that result is mathematically correct but statistically meaningless as a population-level estimate.



The overall 3.12% repeat-customer rate and the 3.04% eligible-cohort repeat rate use different populations and should not be treated as conflicting figures.



\## 7. Customer Reviews and Delivery Experience



\### 7.1 Review-quality checks



The SQL investigates missing and out-of-range review scores and multiple review records associated with orders.



It compares review scores and written-comment rates across delivery-timing groups, including the documented delay bands.



\### 7.2 Average review score by delivery timing



| Delivery timing | Average review score |

|---|---:|

| On time or early | 4.29 |

| 1–7 days late | 2.72 |

| 8–30 days late | 1.65 |

| More than 30 days late | 2.06 |



The more-than-30-days-late group contains \*\*329 observations in the documented analysis\*\*. Its average is less stable than estimates from larger groups, and the pattern is not strictly monotonic.



The results show an association between delivery delay and review scores. They do not establish that delivery delay alone caused a particular review score.



\### 7.3 Written-comment rates



The documented written-comment rate increases with delivery delay, from \*\*40.93% for on-time deliveries\*\* to \*\*64.44% for deliveries 8–30 days late\*\*.



This pattern suggests that delayed deliveries are associated with a greater likelihood of customers leaving written feedback. It does not establish the reason for every comment.



\### 7.4 Exploratory review issue flags



The analysis includes keyword-based flags for themes such as:



\- Nonreceipt

\- Incomplete orders

\- Service issues

\- Product issues



The documented review population and flag results are:



\- \*\*42,697 written reviews\*\*

\- \*\*6,203 reviews with at least one issue flag\*\*

\- Approximately \*\*14.53%\*\* of written reviews flagged



The recorded low-score flag rate is approximately \*\*39.41%\*\*, compared with \*\*4.50%\*\* for high-score reviews.



Additional documented comparisons include:



| Review theme | Low-score written reviews | High-score written reviews |

|---|---:|---:|

| Nonreceipt keywords | 23.39% | 0.50% |

| Incomplete-order keywords | 3.09% | 0.35% |

| Service keywords | 8.50% | 3.05% |



The product-issue analysis recorded 768 matches under the original rule and 705 under the refined rule in low-score reviews. The original rule was retained, with its false-positive risk explicitly acknowledged.



Keyword matches are exploratory indicators, not confirmed classifications of every review. Overlapping issue themes also mean that a review can be associated with more than one flag.



\## 8. Product-Category Performance



\### 8.1 Category analysis



The category analysis calculates item sales, order counts, average item prices, category concentration, and classification-quality checks.



Item sales exclude freight. Unknown or unclassified products are kept visible rather than silently assigned to a known category.



\### 8.2 Recorded findings



| Finding | Recorded result |

|---|---:|

| Health \& Beauty (`beleza\_saude`) item sales | R$1,258,681.34 |

| Health \& Beauty share of all item sales | 9.26% |

| Health \& Beauty share of classified-category sales | 9.38% |

| Watches \& Gifts (`relogios\_presentes`) item sales | R$1,205,005.68 |

| Highest order count: Bed, Bath \& Table (`cama\_mesa\_banho`) | 9,417 |

| Top-five categories' share of classified-category sales | Approximately 40.27% |

| Unknown or unclassified item sales | R$179,535.28 |

| Unknown or unclassified share of all item sales | Approximately 1.32% |

| Documented category-level reconciliation difference | R$0.00 |



The different Health \& Beauty percentages use different denominators: all item sales versus classified-category sales.



The top-five concentration figure uses classified-category sales as its denominator. These denominator definitions should be retained in any dashboard or presentation.



\### 8.3 Classification exceptions



The modeling checks recorded 610 products with NULL category values and 13 products whose categories did not match the translation table.



The category analysis also documents one product with fully missing attributes: product ID `5eb564652db742ff8f28759cd8d2652a`, associated with 17 order items, 15 orders, and R$563.00 in item value.



These exceptions demonstrate why product completeness and classification coverage matter when interpreting category performance.



\## 9. Payment Behavior



The payment analysis covers:



\- Payment-method mix

\- Installment distribution

\- Payment method by installment count



These analyses help describe how customers pay and how installment behavior differs across payment methods.



The results should be interpreted using the payment-record grain and the aggregation rules documented in the SQL. The analysis does not, by itself, establish why customers select a payment method or installment plan.



\## 10. Seller Performance



The seller analysis examines individual seller performance and seller delivery outcomes.



The documented approach counts a multi-seller order once for each seller associated with that order in seller-level delivery analysis. Consequently, seller-level counts may sum to more than the number of unique orders.



Seller comparisons should be interpreted alongside order volumes and the documented inclusion rules. A high or low delivery rate alone does not establish the reason for a seller's performance.



\## 11. Excel Outputs and Validation



The SQL script includes export operations for the analysis areas below:



| Export area | Focus |

|---|---|

| 4A | Delivery performance |

| 4B | Monthly order trends |

| 4B.2 | Monthly payment value |

| 4C | Product-category performance and reconciliation |

| 4D | Customer frequency, second-purchase gaps, and 180-day cohorts |

| 4E | Review-score distributions, comment rates, review populations, and issue flags |

| 4F | Payment methods and installments |

| 4G | Individual seller and delivery performance |



The `Mission\_4D\_Customer\_Analysis.xlsx` workbook was checked against the corresponding SQL validation targets. The customer totals, frequency distribution, second-purchase count, average purchase gap, cohort totals, and gap distribution were consistent with the recorded SQL results.



The workbook's floating-point percentage total of `99.99999999999999` is a numerical representation artifact rather than a meaningful difference from 100%.



Some pivot sections are placeholders without data; they should not be presented as completed analyses.



\## 12. Metric Definitions and Limitations



1\. \*\*Grain:\*\* Orders, order items, payment records, reviews, and unique customers are different analytical populations.

2\. \*\*Revenue and payment value:\*\* Recorded payments and item-plus-freight totals are distinct measures and require explicit reconciliation.

3\. \*\*Delivery timing:\*\* Timestamp-based and calendar-day calculations can produce different on-time counts. The primary Power BI KPI definition must be confirmed and used consistently.

4\. \*\*Repeat purchasing:\*\* Same-day second orders are included in the documented repeat-customer metric; this does not necessarily represent long-term retention.

5\. \*\*Cohort analysis:\*\* Small eligible populations produce unstable percentages.

6\. \*\*Review flags:\*\* Keyword rules are exploratory, can generate false positives, and may overlap across themes.

7\. \*\*Product categories:\*\* Missing and unclassified attributes affect category coverage and should remain transparent.

8\. \*\*Geographic analysis:\*\* Minimum-order thresholds and exclusions affect which orders are represented in state-level comparisons.

9\. \*\*Seller analysis:\*\* Multi-seller orders may be counted once per associated seller.

10\. \*\*Interpretation:\*\* The findings are descriptive. They identify patterns and associations but do not independently prove causation.



\## 13. Business Implications



The documented results suggest several areas for further investigation:



\- \*\*Delivery experience:\*\* Investigate the operational causes of delays and assess whether improvements correspond with better customer feedback.

\- \*\*Customer retention:\*\* Examine repeat purchasing using clearly defined eligibility windows and separate same-day purchasing from longer-term repeat behavior.

\- \*\*Payment integrity:\*\* Prioritize investigation of large order-level reconciliation discrepancies.

\- \*\*Product classification:\*\* Improve category completeness and maintain explicit treatment of unclassified products.

\- \*\*Customer feedback:\*\* Use validated review themes as exploratory signals for operational investigation, not as definitive issue labels.

\- \*\*Seller operations:\*\* Compare delivery performance alongside seller order volumes and coverage.



These are analytical follow-up opportunities, not proven causal conclusions or quantified financial forecasts.



\## 14. Summary



The business-analysis phase combines SQL investigation, reconciliation, Excel analysis, and Power BI reporting to examine the Olist e-commerce operation across orders, payments, delivery, customers, reviews, product categories, and sellers.



The strongest analytical contribution is the combination of business metrics with explicit data-grain rules, reconciliation checks, validation evidence, and documented limitations.



Reliable recommendations depend on clearly defined metrics, validated populations, and a transparent account of what the data supports.



