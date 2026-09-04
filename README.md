# DataCo Smart Supply Chain — Predicting Late Delivery Risk

Portfolio project 2, following [Olist Brazilian E-Commerce (project 1)](#) — a full MySQL + Tableau BI pipeline. This project shifts from descriptive dashboards to a predictive question, and introduces Python (pandas, scikit-learn) alongside SQL.

**Question:** what predicts a late delivery, and how much?

## Repository structure

```
sql/
  01_create_database.sql
  02_create_tables.sql
  03_data_import.sql
  04_data_check.sql
  05_data_cleaning.sql
notebooks/
  01_load_data.ipynb            # MySQL → pandas, saves data/processed/supply_chain_clean.parquet
  02_eda.ipynb                  # exploration, saves data/processed/supply_chain_eda.parquet
  03_feature_engineering.ipynb  # cleaning + features, saves data/processed/supply_chain_fe.parquet
  04_modeling.ipynb             # train/test split, pipelines, evaluation
```

Each notebook loads the previous stage's saved snapshot rather than depending on shared kernel state — any notebook can be rerun independently from its own checkpoint.

## Dataset

[DataCo Smart Supply Chain](https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis) (Kaggle), two raw tables:

- **`supply_chain`** — order-item grain, 180,519 rows, ships with a `late_delivery_risk` label.
- **`tokenized_access_logs`** — product browsing/access log data. **Evaluated and excluded** from this analysis: it carries no `order_id` or `customer_id`, so it cannot be joined to `supply_chain` at the row level — using it would mean answering a different question (e.g. browsing patterns by hour/department) rather than deepening the late-delivery question. It was still imported and validated (character-length truncation checks, CRLF line-ending fix) as part of full raw-data ingestion, and is a candidate for a separate future project rather than folded into this one.

## Pipeline & cleaning decisions

- Raw import: `latin1` charset (source encoding), decimals widened to `DOUBLE` to avoid truncation, `NULLIF` for empty zipcodes, `STR_TO_DATE` for date parsing. Line terminator corrected to `\r\n` after a stray `\r` was found appended to `shipping_mode` (last column in each row).
- **Leakage removed:** `delivery_status` and `days_for_shipping_real` dropped — `late_delivery_risk` is derived directly from `delivery_status` (100% match), and `days_for_shipping_real` agrees with the label on 97.5% of rows. Both are effectively the answer, not usable features.
- **Canceled orders excluded** (7,754 rows, 4.3%) — cancellation was confirmed independent of the lateness calculation (splits ~43/57 between what would have been on-time vs. late), so it's a separate outcome. Question reframed as: *given a shipment happens, is it late?*
- **PII / high-cardinality IDs dropped:** customer name/email/password/street, `customer_id`, `order_id`, product description/image, redundant ID columns, zipcodes.
- **Duplicate columns identified via `.equals()` and dropped:** `order_item_product_price` (dup of `product_price`), `benefit_per_order` (dup of `order_profit_per_order`), `sales_per_customer` (dup of `order_item_total` — misleadingly named, it's order-item grain, not a customer aggregate). `category_id`/`product_category_id` duplication confirmed and resolved at the SQL layer (0 mismatches).
- **`days_for_shipment_scheduled` dropped** — carries near-duplicate information to `shipping_mode` (see finding below); `shipping_mode` kept as the more interpretable of the two.
- `order_item_id` kept as the pandas index rather than dropped, preserving row traceability without it entering the feature space.

**Result:** 172,765 rows, zero missing values, no negative prices, no discount rates above 1.0, `order_date` always ≤ `shipping_date`.

## Key EDA findings

- **Target balance:** 57.3% late vs. 42.7% not late — close enough to balanced that no resampling/class-weighting was needed.
- **`shipping_mode` is the dominant predictor, and the mechanism behind it is the most useful finding in this project:** First Class → 100% late, Second Class → 79.8%, Same Day → 47.9%, Standard Class → 39.8%. Investigating why revealed `days_for_shipment_scheduled` has **zero variance within each shipping mode** — First Class is always promised in exactly 1 day, Standard Class always 4. Much of what this dataset calls "late" is a direct consequence of an unrealistically tight promise on faster shipping tiers, not evidence of operational failure. Fixing the SLA on First/Second Class would likely reduce "late" labels more than speeding up fulfillment itself.
- **A genuine mislabeled-category collision:** `category_name` is *not* 1:1 with `product_category_id` — "Electronics" is shared by two distinct category IDs (13 and 37) that turned out to belong to two different departments (Footwear and Outdoors). Resolved by building a disambiguated `category_label` column (`"Electronics (Footwear)"` vs. `"Electronics (Outdoors)"`) rather than silently merging two real categories.
- **High-cardinality geography excluded from the baseline:** `order_state` (1,083 values, mixed international granularity), `order_city` (3,585), `customer_city` (563), `order_country` (164), `product_name` (118) — parked in favor of `order_region` (23) and `category_label` (51).

## Feature engineering

- `order_weekday`, `order_date_month` extracted from `order_date` (treated as categorical, not numeric — weekday/month are labels, not real quantities).
- `category_label` built to resolve the Electronics collision above.
- `product_status` dropped (zero variance — carried no information).

Final feature set: 9 categorical (`shipping_mode`, `payment_type`, `customer_segment`, `market`, `department_name`, `order_region`, `category_label`, `order_date_month`, `order_weekday`) + 6 numeric (`order_item_discount`, `order_item_discount_rate`, `order_item_quantity`, `product_price`, `order_item_total`, `order_profit_per_order`).

## Modeling

Preprocessing: `ColumnTransformer` — `OneHotEncoder(handle_unknown='ignore', drop='first')` for categoricals, `StandardScaler` for numerics — wrapped in a `Pipeline` with each classifier, fit only on the training split (80/20, stratified).

| Model | Accuracy | ROC-AUC | Precision (late) | Recall (late) | Missed late orders | False alarms |
|---|---|---|---|---|---|---|
| Logistic Regression | 0.70 | 0.74 | 0.88 | 0.55 | 8,993 | 1,445 |
| Random Forest | 0.70 | 0.77 | 0.78 | 0.67 | 6,561 | 3,783 |

**Naive baseline** (always predicting the majority class): 57.3% accuracy. Both models clear this by ~13 points using only information available at order time.

## Key conclusions

1. **Accuracy alone would completely hide the real difference between these two models** — both land at 0.70, yet they behave very differently underneath: logistic regression is conservative (fewer false alarms, misses more real late orders), the random forest catches substantially more real lates at the cost of more false alarms. A single summary metric would never have surfaced this. **ROC-AUC confirms the random forest is a genuinely stronger model overall** (0.77 vs. 0.74) rather than just a different threshold trade-off — since ROC-AUC evaluates ranking quality across every possible decision threshold, not only the default 50% cutoff used above.
2. **Logistic regression's coefficients confirm the shipping-mode mechanism directly**, once `drop='first'` removed a redundancy in the encoding: relative to First Class (the implicit reference), Standard Class (-7.18), Same Day (-6.83), and Second Class (-5.40) all sharply reduce the odds of lateness — a clean, interpretable readout matching the EDA finding.
3. **The random forest closes part of the recall gap by using order-economics features** (`order_profit_per_order`, `order_item_total`, `order_item_discount`) alongside shipping mode — features the linear model underweighted relative to shipping mode. This lets it distinguish late from not-late *within* a shipping mode, where the linear model has little else to go on.
4. **Neither model is precise enough for a fully autonomous gate**, but both are legitimate as a **decision-support signal** — flagging higher-risk orders for review has real value even under imperfect precision. Which model is "better" depends on the real cost of a missed late order vs. a false alarm — a business judgment, not something the metrics alone resolve.

**Did the project answer its original question?** Yes. The question was exploratory — what predicts lateness, and how much — not a mandate to hit a specific accuracy target. Shipping-mode-driven scheduling explains most of what's labeled "late" in this dataset, order economics explain a meaningful amount on top of that, and the gap between the two models is quantified and explained rather than left as an unexplained number.

## Business Recommendations

1. **Revisit the promised delivery window for First and Second Class shipping.** `days_for_shipment_scheduled` is a fixed rule, not a case-by-case estimate — tightening or loosening it directly reshapes the "late" rate more than any fulfillment speed-up would. First Class's 1-day promise being broken almost every time suggests it's overcommitted relative to what fulfillment can reliably deliver.
2. **Use model output as a triage signal, not an automated gate.** Given the precision/recall trade-off found here, flagging high-risk orders (the random forest's higher recall makes it the stronger choice for this) for manual review or proactive customer communication captures real value without requiring near-perfect accuracy.
3. **Investigate order-value/discount handling in fulfillment.** The random forest's reliance on `order_profit_per_order`, `order_item_total`, and `order_item_discount` suggests larger or heavily discounted orders may be handled differently in fulfillment than the SLA data alone explains — worth an operational follow-up outside the scope of this analysis.

## On pushing further

Adjusting the classification threshold (currently 50%) trades recall for precision using the same trained model's existing probabilities — a legitimate business-tuning conversation, but not a source of genuine improvement, since it doesn't change the model's underlying ability to separate the two classes. Real improvements — hyperparameter tuning, gradient boosting (XGBoost/LightGBM), richer engineered features — are documented here as **future work**, consistent with this project's scope decision to stay narrow and complete rather than open-ended.

## Reproducing this project

1. `pip install -r requirements.txt`
2. Run `sql/01` through `sql/05` in order against a local MySQL instance (adjust the `LOAD DATA INFILE` paths to your own CSV location).
3. Run `notebooks/01` through `notebooks/04` in order (each depends on the previous notebook's saved parquet checkpoint).
