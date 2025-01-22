# CLOSED ENDED QUESTION

#2 What are the top 5 brands by sales among users that have had their account for at least six months?

-- CTE 1: Filter users who have had an account for at least six months.
WITH Filtered_Users AS (
    SELECT 
        ID AS USER_ID  
    FROM Users
    WHERE DATEDIFF('2025-01-17', CREATED_DATE) >= 180  -- Only include users with accounts older than 180 days
),

-- CTE 2: Filter, deduplicate, and clean transactions.
Valid_Transactions AS (
    SELECT 
        t.RECEIPT_ID,
        t.BARCODE,
        MAX(t.FINAL_SALE) AS SALE_AMOUNT -- Choose the record with the highest sale amount in cases of duplicates
    FROM Transactions t
    WHERE t.USER_ID IN (SELECT USER_ID FROM Filtered_Users) -- Only consider transactions from filtered users
      AND t.FINAL_QUANTITY != 'zero'  -- Exclude records where the quantity is "zero"
      AND t.FINAL_SALE IS NOT NULL    -- Exclude records where the sale amount is NULL
      AND t.BARCODE IS NOT NULL       -- Exclude records where the barcode is NULL
    GROUP BY t.RECEIPT_ID, t.BARCODE -- Group by receipt and barcode to deduplicate
),

-- CTE 3: Aggregate sales data by brand.
Brand_Sales AS (
    SELECT 
        p.BRAND, 
        SUM(vt.SALE_AMOUNT) AS TOTAL_SALES -- Total sales amount for the brand
    FROM Valid_Transactions vt
    INNER JOIN Products p
        ON vt.BARCODE = p.BARCODE  -- Match transactions to products using the barcode
    WHERE p.BRAND IS NOT NULL      -- Exclude NULL brand values
    GROUP BY p.BRAND               -- Group sales data by brand
)

-- CTE 4: Fetch the top 5 brands based on total sales.
SELECT 
    BRAND, 
    TOTAL_SALES     
FROM Brand_Sales
ORDER BY TOTAL_SALES DESC  -- Sort brands by total sales in descending order
LIMIT 5;                   -- Limit the result to the top 5 brands

/* OUTPUT
---------------------------------------------------
|     BRAND       |     TOTAL_SALES               |
---------------------------------------------------
|     CVS         |       72.00                    |
|     DOVE        |       30.91                    |
|     TRIDENT     |       23.36                    |
|     COORS LIGHT |       17.48                    |
|     TRESEMMÉ    |       14.58                    |
---------------------------------------------------
*/


# OPEN ENDED QUESTION

/*
#1 Who are Fetch’s power users?

ASSUMPTIONS:  
Assuming that the business goal for Fetch is to identify highly engaged users who contribute significantly to the platform’s activity and revenue, following are my assumptions -
   1. SCAN_DATE is when the User submits his receipt for his puchase on the PURCHASE_DATE
   2. Power users are defined as those who submit at least X receipts per month on average, where X = 5 or a business-defined threshold. 
   3. Monthly receipt submission frequency indicates engagement, as users earn points by submitting receipts.
*/

-- CTE 1: Get the monthly receipt count for each user
WITH Monthly_Receipt_Count AS (
    SELECT 
        t.USER_ID,  
        YEAR(t.SCAN_DATE) AS TRANSACTION_YEAR,  
        MONTH(t.SCAN_DATE) AS TRANSACTION_MONTH, 
        COUNT(t.RECEIPT_ID) AS MONTHLY_RECEIPTS  -- Count of receipts submitted by the user in that month
    FROM Transactions t
    GROUP BY t.USER_ID, YEAR(t.SCAN_DATE), MONTH(t.SCAN_DATE) 
),
-- CTE 2: Identify power users by filtering users who have at least 5 receipts per month on average
Power_Users AS (
    SELECT 
        mrc.USER_ID,  -- User ID
        COUNT(DISTINCT CONCAT(mrc.TRANSACTION_YEAR, '-', mrc.TRANSACTION_MONTH)) AS MONTHS_ACTIVE,  -- Number of distinct months the user was active (i.e., submitted receipts in at least one month)
        SUM(mrc.MONTHLY_RECEIPTS) AS TOTAL_RECEIPTS  -- Total number of receipts the user has submitted
    FROM Monthly_Receipt_Count mrc
    GROUP BY mrc.USER_ID  -- Group by user to aggregate receipt data
    HAVING SUM(mrc.MONTHLY_RECEIPTS) / COUNT(DISTINCT CONCAT(mrc.TRANSACTION_YEAR, '-', mrc.TRANSACTION_MONTH)) >= 5  -- Only include users who submit at least 5 receipts per month on average
)
-- CTE 3: Fetch user details (state, language, gender) for power users and calculate their average receipts per month
SELECT 
    pu.USER_ID, u.STATE, u.LANGUAGE, u.GENDER,  
    pu.TOTAL_RECEIPTS / pu.MONTHS_ACTIVE AS AVG_RECEIPTS_PER_MONTH  -- Average number of receipts submitted per month
FROM Power_Users pu
INNER JOIN Users u
    ON u.ID = pu.USER_ID  -- Join the Users table to get user details
ORDER BY AVG_RECEIPTS_PER_MONTH DESC;  -- Order by the highest average receipts per month first


/* OUTPUT
-------------------------------------------------------------------------------------------
|            USER_ID             | STATE | LANGUAGE | GENDER | AVG_RECEIPTS_PER_MONTH     |
-------------------------------------------------------------------------------------------
| 6528a0a388a3a884364d94dc        |  WV   |    en    | female |          6.0              |
| 5f64fff6dc25c93de0383513        |  GA   |    en    |  male  |          6.0              |
-------------------------------------------------------------------------------------------
*/


/*
#2 Which is the leading brand in the Dips & Salsa category?

ASSUMPTIONS:
Assumng that the business goal is for Fetch to find out which Brand is leading in terms of Sales Revenue in the Dips & Salsa category, following are my assumptions -
	1. The "Dips & Salsa" category is defined by the CATEGORY_2 field in the Products dataset.
	2. The leading brand is determined based solely on the total sales (SUM of FINAL_SALE) in the "Dips & Salsa" category.
	3. Only valid transactions are considered to calculate sale:
	   - FINAL_SALE must not be NULL.
	   - FINAL_QUANTITY must not be "zero".
	   - BARCODE must not be NULL.

*/

-- CTE 1: Clean Transactions Dataset: Filter the Transactions dataset to remove invalid data and handle duplicates.
WITH Clean_Transactions AS (
    SELECT 
        t.RECEIPT_ID, t.BARCODE,                    
        MAX(t.FINAL_SALE) AS SALE_AMOUNT -- Take the highest sale amount per receipt and product to handle duplicates
    FROM Transactions t
    WHERE t.FINAL_SALE IS NOT NULL         -- Exclude records with missing (NULL) sales amounts
      AND t.FINAL_QUANTITY != 'zero'       -- Exclude records where the purchased quantity is explicitly marked as "zero"
      AND t.BARCODE IS NOT NULL            -- Exclude records with missing (NULL) barcodes
    GROUP BY t.RECEIPT_ID, t.BARCODE       -- Group by receipt and barcode to remove duplicates
),

-- CTE 2: Filter Products in the "Dips & Salsa" Category: Extract only the products that belong to the "Dips & Salsa" category.
Dips_Salsa_Products AS (
    SELECT 
        BARCODE, BRAND                          
    FROM Products
    WHERE CATEGORY_2 = 'Dips & Salsa' 
      AND BARCODE IS NOT NULL              -- Exclude products with missing (NULL) barcodes
),

-- CTE 3: Join Transactions and Filtered Products: Combine the cleaned transactions with the filtered products dataset to get only on transactions related to the "Dips & Salsa" category.
Dips_Salsa_Sales AS (
    SELECT 
        dsp.BRAND, ct.SALE_AMOUNT                
    FROM Clean_Transactions ct
    INNER JOIN Dips_Salsa_Products dsp
        ON ct.BARCODE = dsp.BARCODE        -- Join transactions to products using the barcode
),

-- CTE 4: Aggregate Sales by Brand: Calculate the total sales for each brand in the "Dips & Salsa" category.
Brand_Sales AS (
    SELECT 
        BRAND,                         
        SUM(SALE_AMOUNT) AS TOTAL_SALES -- Total sales amount for each brand
    FROM Dips_Salsa_Sales
    GROUP BY BRAND                     -- Group by brand to calculate total sales
)

-- CTE 6: Identify the Leading Brand: Retrieve the brand with the highest total sales in the "Dips & Salsa" category.
SELECT 
    BRAND, TOTAL_SALES                        
FROM Brand_Sales
ORDER BY TOTAL_SALES DESC              -- Sort by total sales in descending order
LIMIT 1;                               -- Select only the brand with the highest total sales

/* OUTPUT
-------------------------------
|      BRAND     | TOTAL_SALES |
-------------------------------
|    TOSTITOS    |    181.3    |
-------------------------------
*/
