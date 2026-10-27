\# Olist E-Commerce Analytics — Data Model Documentation



\## 1. Purpose



This document describes the data-modeling work implemented in `phase2\_data\_modeling.sql` for the Olist E-Commerce Analytics project.



The modeling phase prepares source data for reliable business analysis by checking identifiers and relationships, establishing analytical table structures, investigating data-quality exceptions, and validating data consistency.



The objective is to make downstream SQL analysis, Excel analysis, and Power BI reporting more reliable and reproducible.



\## 2. Source and Implementation



\- \*\*Database:\*\* `olist\_analytics`

\- \*\*Primary modeling script:\*\* `SQL/phase2\_data\_modeling.sql`

\- \*\*Source dataset:\*\* Brazilian Olist E-Commerce Public Dataset

\- \*\*Downstream use:\*\* Business analysis, Excel workbooks, and Power BI reporting



The script combines modeling operations with validation queries. Its presence documents the intended checks and transformations; a check should be described as passed only when its execution results confirm that outcome.



\## 3. Analytical Grain and Entity Relationships



The project contains several types of business entities. Each must be analyzed at its appropriate grain.



| Entity | Analytical grain | Key consideration |

|---|---|---|

| Customers | Customer record | Customer identifiers and customer-level attributes must be handled consistently. |

| Orders | One row per order | Order status and order-level metrics belong at this grain. |

| Products | One row per product | Product attributes and category classification belong at this grain. |

| Sellers | One row per seller | Seller identifiers and seller-level attributes must be unique. |

| Order items | One row per order-item combination | An order can contain multiple items; order-level totals must not be duplicated by item joins. |

| Payments | One row per payment record | An order can have multiple payment records. Payment rows must not be assumed to equal order counts. |

| Reviews | One row per review record, subject to the source structure | Review multiplicity must be checked before associating reviews with orders. |



These grains are important because joins between orders, order items, payments, and reviews can multiply rows. Counts, sums, and averages must use the correct entity and aggregation level.



\## 4. Modeling and Validation Scope



\### 4.1 Identifier and uniqueness checks



The modeling script includes checks for identifiers and duplicate records across key entities, including customers, orders, products, sellers, order items, payments, and reviews.



These checks help identify potential violations of the expected table grain and support reliable joins between entities.



For order items, the order-item combination is particularly important because an order may contain multiple line items.



\### 4.2 Relationship and referential-integrity checks



The script investigates relationships between analytical entities and checks for records that do not have corresponding parent records.



These checks include the identification of unmatched or orphan records and validation of expected relationships between orders and related entities.



A relationship check is considered successful only when the executed results support the expected relationship.



\### 4.3 Analytical model tables



The script creates analytical model structures, including:



\- `customers\_model`

\- `orders\_model`

\- `products\_model`



These tables support downstream analysis by providing modeled representations of source entities.



The script also contains modeling and validation work for other business entities and their relationships. The exact final schema and constraints should be taken from the SQL definitions rather than inferred from table names alone.



\### 4.4 Product-category completeness



Product-category modeling includes checks for missing category values and category-translation matches.



The recorded findings include:



\- \*\*610 products\*\* with a NULL product-category value.

\- \*\*13 products\*\* associated with categories without a matching translation.



These exceptions should remain visible in the analysis rather than being silently assigned to an invented category. Downstream reporting should distinguish classified products from unknown or unclassified products where relevant.



\### 4.5 Row-count reconciliation



The script includes row-count reconciliation and consistency checks intended to identify unexpected changes in data volume between source and modeled structures.



Row counts should be interpreted alongside the table grain and any documented filtering or transformation rules. Different counts do not automatically indicate an error if the tables represent different populations.



\### 4.6 Duplicate and orphan-record checks



Duplicate checks help verify expected uniqueness. Orphan-record checks help determine whether dependent records reference valid parent entities.



These checks are especially important before joining multiple transactional tables for revenue, payment, delivery, and customer analysis.



\## 5. Data-Quality Principles



The modeling approach follows these principles:



1\. \*\*Preserve the correct grain.\*\* Do not treat an order, an order item, a payment record, and a customer as interchangeable units.

2\. \*\*Validate keys before relying on relationships.\*\* Identifier uniqueness and referential integrity should be checked explicitly.

3\. \*\*Investigate missing attributes.\*\* Missing categories and unmatched translations should be documented.

4\. \*\*Reconcile data volume.\*\* Compare row counts and totals where the underlying populations are expected to match.

5\. \*\*Avoid unsupported assumptions.\*\* A table or validation query does not, by itself, prove that every check passed.

6\. \*\*Maintain traceability.\*\* Keep the SQL script as the implementation record and use this document to explain its purpose and analytical implications.



\## 6. Known Exceptions and Limitations



The recorded product-category checks identify missing category values and unmatched translations. These cases can affect category-level summaries if their treatment is not made explicit.



The project also contains transactional tables with different grains. Joins across these tables require careful aggregation to avoid double-counting.



The recorded exception counts should be treated as documented findings from the modeling work, not as evidence that every other data-quality check passed.



\## 7. Relationship to Downstream Analysis



The modeled data supports the project's business-analysis work, including:



\- Monthly order and payment trends

\- Payment coverage and reconciliation

\- Delivery performance and geographic analysis

\- Customer purchasing frequency and repeat behavior

\- Customer reviews and delivery-related review patterns

\- Product-category sales performance

\- Payment-method and installment analysis

\- Individual seller performance



These analyses rely on consistent definitions, valid relationships, and correct aggregation levels.



\## 8. Reproducibility and Maintenance



To reproduce or review the modeling work:



1\. Open `SQL/phase2\_data\_modeling.sql`.

2\. Identify the source tables and model-table definitions.

3\. Execute the modeling operations in the intended sequence.

4\. Run the associated validation queries.

5\. Record the actual results, including any failed checks or exceptions.

6\. Compare the modeled data with the downstream business-analysis outputs where the populations and definitions are expected to match.



If the model structure changes, update this document to reflect the actual SQL implementation.



\## 9. Summary



The modeling phase establishes the structural and validation foundation for the Olist analytics project. Its main contribution is to make entity grain, relationships, missing attributes, and data consistency explicit before business metrics are interpreted.



The modeling SQL and its execution results remain the authoritative references for the precise implementation and validation status.



