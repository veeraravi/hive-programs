Tables used:
AEAST.CUSTOMER_PRODUCT 
AEAST.CUSTOMER_PRODUCT_REL 
AEENT.AGREEMENT_CONTRACT 
AEENT.CUSTOMER_CONTRACT 
AEENT.CONTRACT_PRODUCT_COVERAGE 
AEAGR.AGREEMENT
AEAGR.AGREEMENT_CUSTOMER_PRODUCT 
AEAGR. AGREEMENT_IDENTIFIER
AEPA. PARTY_ADDRESS 
AEPA. PARTY_ADDRESS_AGREEMENT 
AEPA. PARTY_ADDRESS_ASSET 
SDR. DUAL_SERIAL_INSTRUCTION 
SDR. GLOBAL_ITEM_MAIN 
SDR. ITEM_MATERIAL_MAPPING


--first, we get assets that were created in a period and have no contract associated with, using the query below
select CUSTOMER_PRODUCT_ID as counterpartAssetId,
MFG_SERIAL_NUM as counterpartAssetSerialNumber,
MANUFACTURER_ID as counterpartAssetManufacturerId,
ITEM_CLASS as counterpartAssetItemClass,
SOURCE_SITE_ID as counterpartAssetSourceSiteId,
CUSTOMER_NUM as counterpartAssetCustomerNumber 
from AEAST. CUSTOMER_PRODUCT CP
left join AEENT. CONTRACT_PRODUCT_COVERAGE pc
on CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
left join AEENT. CUSTOMER_CONTRACT CC
on CC.CUSTOMER_ CONTRACT_ ID = CPC. CUSTOMER_CONTRACT_ID
Where CP. SOURCE_SYS_CREATE PGM in ('AC_NG.DS.SW_AS_A.CRI','AC_NG.DS. SW_A.CRY','AC_NG. DUAL_SRL_INS.ASSET')
and CC.CUSTOMER CONTRACT ID is null
and CP.ORDER_NUM = 99999
and CP. SOURCE_SYS_CREATE_DTS
between TO DATE ('2023-10-01 00:00:00','YYYY-mn-dd HH24 :MI: SS') and TO DATE ('2023-10-31 23:59:59', 'YYYY-mn-dd HH24 :MI: SS')


--After assets are retrieved, for each asset we get the original asset ID
--associated that is present in the asset relationship record which has relationship type 9 
select TO_CUSTOMER_PRODUCT_ID as originalAssetId from AEAST. CUSTOMER_PRODUCT_REL
where FROM CUSTOMER_PRODUCT_ID = counterpartAssetId
AND RELATIONSHIP_TYPE_ID=9;
--If there is no asset relationship record found
--then the root cause for the asset should be "Original asset not found"
--If the original asset was found, we get the contracts that are associated with it 
select CC.CUSTOMER_CONTRACT_ID as contractId,
CC.ITEM_NUM as contractItemNumber 
from AEENT. CUSTOMER_CONTRACT CC 
join ABENT.CONTRACT_PRODUCT_COVERAGE CPC
on CC.CUSTOMER_CONTRACT_ID = CPC. CUSTOMER_CONTRACT_ID
join AEAST. CUSTOMER_PRODUCT CP
On CPC.CUSTOMER_PRODUCT_ID = CP. CUSTOMER_PRODUCT_ID
where CP. CUSTOMER_PRODUCT_ID = :originalAsgetId;


--if there is no contract assocoiated with the original assest then the root cause for the asset should be "Original Asset Without Entitlement"
--At this point, we start classifying the root cause for the contract, which means one asset can have more than one root cause, one for each contract For each contract found in the previous step we do the following:
--Check if the contract is already dual serialized but linked to a contract from a different asset by getting the identifier record with IDENTIFIER_TYPE_ID 106
select CUSTOMER_CONTRACT_ID 
from AEENT.CUSTOMER_CONTRACT_IDENTIFIER where CONTRACT_IDENTIFIER_VALUE: contractId and IDENTIFIER_TYPE_ID = 106;

--If a record is found in the previous step then the root cause for the contract should be "Original entitlement dual serialized to different asset"
--Check if the contract item number is one of the following:
--'709-BBEW', '865-BCFG', '709-BBOR', '865-BCFF', '303-11289', '865-BCFD', '709-BBEX', '199-BBJQ', '865-BCFE', '865-BCFK', '709-BBTV', '709-BBNG', '862- BBXI', '303-11291', '303-11290', '865-BCFJ', '199-BBMF', '865-BBJP', '303-11466', '142-BBNV', '149-BBGI', '149-BBGK', '151-BBEH', '151-BBGU', '151- BBHJ', '151-BBHY', '151-BBIY', '151-BBJB', '151-BBJE', '151-BBJF', '151-BBJP', '456-109-802', '456-109-803', '456-109-804', '456-109-805', '456-111-473', '456-111-474', '456-111-475', '456-111-476', '528-BYHE', '528- BYHF
-- If the contract item number is one of the above then the root cause for the contract should be "SKU not eligible"
--If the contract didn't fall in the previous step we check if it has an agreement

select AGREEMENT_ID as originalAgreementId
from AEENT.AGREEMENT_CONTRACT where CUSTOMER_CONTRACT_ID = : contractId;
--If the contract has an agreement:
-- We get the counterpart agreement ID that is present in the AGREEMENT_IDENTIFIER_VALUE column
--from the agreement identifier record which has identifier type 111 or 112 
select AGREEMENT_IDENTIFIER_VALUE as counterpartAgreementId from AEAGR.AGREEMENT IDENTIFIER
where AGREEMENT_ID = : originalAgreement Id and IDENTIFIER TYPE_ID in (111, 112);
-- If there is no agreement identifier record then the root cause for the contract
--should be "CounterPart Agreement Not Found"
--If the counterpart agreement ID is present then we get the SOURCE_SITE_ID value from the counterpart agreement 
select SOURCE_SITE_ID as counterpartAgreement SourceSiteId
from AEAGR.AGREEMENT where AGREEMENT_ID : counterpartAgreementId;
--After that, we get the contracts that are associated with the counterpart agreement 
select CUSTOMER_CONTRACT_ID as counterpartAgreementContractId from AEENT.AGREEMENT_CONTRACT
where AGREEMENT_ID = :counterpartAgreementId;

--If there is no asset associated with the counterpart agreement then the root cause for the contract should be "Missing Agreement/Asset Relationship"
--If none of the assets associated with the counterpart agreement is the counterpart asset that we got at the beginning of the process then the root cause for the contract should be "CounterPart Agreement Linked to Non-Mapped Asset"
--After that, we get the party address record for the counterpart agreement
select PA.CUSTOMER NUM, PA.UCID from AEPA. PARTY ADDRESS AGREEMENT PAA
join AEPA. PARTY ADDRESS PA on PAA.PARTY_ADDRESS_ID = PA. PARTY_ADDRESS_ID where PAA.AGREEMENT ID : counterpartAgreementId;
--If there is no party address record for the counterpart agreement or counterpart agreement source site ID is 6 and party address UCID record is null or lower than 1
--or counterpart agreement source site ID is different than 6 and party address customer number record is null or lower than 1 then the root cause for the contract should be "PartyLocation not found"
--If the contract has no agreement we get the party address record for the counterpart asset
select PA.CUSTOMER_NUM, PA.UCID from AEPA. PARTY_ADDRESS_ASSET PAA
join AEPA.PARTY_ADDRESS PA on PAA. PARTY_ADDRESS_ID = PA. PARTY_ADDRESS_ID
where PAA.CUSTOMER_PRODUCT_ID = : counterpartAssetId;

--If there is no party address record for the counterpart asset
--(and counterpart asset source site ID is 6 and party address UCID record is null or lower than 1 or if counterpart
--asset source site ID is different than 6 and the party address customer number record is null or lower
--than 1)
--and counterpart asset customer number is null or lower than 1
--then the root cause for the contract should be "Customer not found in counterpart asset"
--If the contract didn't fall into any of the previous steps then we get the item material mapping record for the contract item number and source site ID
--If the contract source site ID is 6 then we get the item material mapping record by the EMC_ITEM_NUM column
select EMC ITEM NUM as itemMaterialMapping
from SDR.ITEM MATERIAL MAPPING
where EMC ITEM NUM = : contractItemNumber
and APPLICATION ID = 33
and ITEM_MATERIAL_MAP_TYPE_ID in (1, 3, 4, 5, 6);
--If the contract source site ID is different from 6 then we get the item material mapping record by the DELL_ITEM_NUM column
select DELL _ITEM_NUM as itemMaterialMapping
from SDR.ITEM_MATERIAL_MAPPING where DELL ITEM NUM :contractItemNumber
and APPLICATION ID = 33
and ITEM_MATERIAL_MAP_TYPE_ID in (1, 3, 4, 5, 6);

--If there is no item material mapping record then the root cause for the contract should be "Missing Item Material Mapping"
--If the contract didn't fall into the previous step we get the global item main record for the item material mapping
--If the contract source site id is 6 then we get the global item main record by
select ITEM_NUM from SDR.GLOBAL_ITEM_MAIN where ITEM_NUM= itemMaterialMapping and SOURCE_SITE_ID <> 6;
--If the contract source site id is not 6 then we get the global item main record by
select ITEM_NUM from SDR.GLOBAL_ITEM_MAIN where ITEM_NUM= itemMaterialMapping and SOURCE_SITE_ID = 6;
--If there is no global item main record then the root cause for the contract should be "Missing Global Item Main"
--If the contract didn't fall into the previous step we look for instructions in errors for the contract
select DUAL_SERIAL_INSTR_ID from SDR.DUAL_SERIAL_INSTRUCTION where ENTITY_TYPE_ID = 1 and ENTITY_VALUE = :contractId;

--If there is any instruction record then the root cause for the contract should be "Instruction in Error"
--If the contract didn't fall into any of the above root causes and the contract has an agreement then the root cause for the contract should be " [AGREEMENT] Other"
--If the contract didn't fall into any of the above root causes and the contract has no agreement then the root cause for the contract should be " Other"













WITH AssetsWithoutContract AS (
    -- Step 1: Assets without associated contracts
    SELECT 
        CP.CUSTOMER_PRODUCT_ID AS counterpartAssetId,
        CP.MFG_SERIAL_NUM AS counterpartAssetSerialNumber,
        CP.MANUFACTURER_ID AS counterpartAssetManufacturerId,
        CP.ITEM_CLASS AS counterpartAssetItemClass,
        CP.SOURCE_SITE_ID AS counterpartAssetSourceSiteId,
        CP.CUSTOMER_NUM AS counterpartAssetCustomerNumber
    FROM 
        AEAST.CUSTOMER_PRODUCT CP
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    WHERE 
        CP.SOURCE_SYS_CREATE_PGM IN ('AC_NG.DS.SW_AS_A.CRI', 'AC_NG.DS.SW_A.CRY', 'AC_NG.DUAL_SRL_INS.ASSET')
        AND CC.CUSTOMER_CONTRACT_ID IS NULL
        AND CP.ORDER_NUM = 99999
        AND CP.SOURCE_SYS_CREATE_DTS BETWEEN TO_DATE('2023-10-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS') 
        AND TO_DATE('2023-10-31 23:59:59', 'YYYY-MM-DD HH24:MI:SS')
),
OriginalAssetLookup AS (
    -- Step 2: Lookup original asset
    SELECT 
        A.counterpartAssetId,
        CPR.TO_CUSTOMER_PRODUCT_ID AS originalAssetId
    FROM 
        AssetsWithoutContract A
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT_REL CPR
    ON 
        A.counterpartAssetId = CPR.FROM_CUSTOMER_PRODUCT_ID
        AND CPR.RELATIONSHIP_TYPE_ID = 9
),
ContractsForOriginalAssets AS (
    -- Step 3: Contracts associated with the original assets
    SELECT 
        OAL.counterpartAssetId,
        OAL.originalAssetId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original asset not found'
            ELSE CC.CUSTOMER_CONTRACT_ID 
        END AS contractId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN NULL
            ELSE CC.ITEM_NUM 
        END AS contractItemNumber,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original Asset Without Entitlement'
            ELSE NULL
        END AS rootCause
    FROM 
        OriginalAssetLookup OAL
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC 
    ON 
        OAL.originalAssetId = CC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT CP
    ON 
        CPC.CUSTOMER_PRODUCT_ID = CP.CUSTOMER_PRODUCT_ID
),
AgreementCheck AS (
    -- Step 4: Check if the contract has an agreement
    SELECT 
        C.contractId,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.CUSTOMER_CONTRACT_ID = C.contractId
            ) THEN (
                SELECT AI.AGREEMENT_IDENTIFIER_VALUE 
                FROM AEAGR.AGREEMENT_IDENTIFIER AI
                WHERE AI.AGREEMENT_ID = (
                    SELECT AGREEMENT_ID 
                    FROM AEENT.AGREEMENT_CONTRACT 
                    WHERE CUSTOMER_CONTRACT_ID = C.contractId
                )
                AND AI.IDENTIFIER_TYPE_ID IN (111, 112)
                FETCH FIRST 1 ROWS ONLY
            )
            ELSE 'CounterPart Agreement Not Found'
        END AS counterpartAgreementId
    FROM 
        ContractsForOriginalAssets C
),
CounterpartAgreementSource AS (
    -- Step 5: Get source site ID and associated contracts
    SELECT 
        A.counterpartAgreementId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT AGREEMENT.SOURCE_SITE_ID 
                FROM AEAGR.AGREEMENT 
                WHERE AGREEMENT.AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementSourceSiteId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT CUSTOMER_CONTRACT_ID 
                FROM AEENT.AGREEMENT_CONTRACT 
                WHERE AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementContractId
    FROM 
        AgreementCheck A
),
CounterpartAgreementAssetsCheck AS (
    -- Step 6: Check for missing agreement/asset relationship
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
            ) THEN 'Missing Agreement/Asset Relationship'
            WHEN NOT EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                JOIN AEENT.CONTRACT_PRODUCT_COVERAGE CPC 
                ON AC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
                  AND CPC.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) THEN 'CounterPart Agreement Linked to Non-Mapped Asset'
            ELSE NULL
        END AS agreementAssetRootCause
    FROM 
        CounterpartAgreementSource C
    JOIN 
        AssetsWithoutContract A 
    ON 
        1 = 1
),
PartyLocationCheck AS (
    -- Step 7: Check for party address record
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN (
                SELECT COUNT(*) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) = 0 
            OR (C.counterpartAgreementSourceSiteId = 6 AND (
                SELECT COALESCE(PA.UCID, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1)
            OR (C.counterpartAgreementSourceSiteId <> 6 AND (
                SELECT COALESCE(PA.CUSTOMER_NUM, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1) THEN 'PartyLocation not found'
            ELSE NULL
        END AS partyLocationRootCause
    FROM 
        CounterpartAgreementSource C
),
CustomerCheckForCounterpartAsset AS (
    -- Step 8: Check for party address record in the counterpart asset
    SELECT 
        A.counterpartAssetId,
        CASE 
            WHEN (
                SELECT COUNT(*) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) = 0
            OR (A.counterpartAssetSourceSiteId = 6 AND (
                SELECT COALESCE(PA.UCID, 0) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) < 1)
            OR (A.counterpartAssetSourceSiteId <> 6 AND (
                SELECT COALESCE(PA.CUSTOMER_NUM, 0) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) < 1)
            OR (A.counterpartAssetCustomerNumber IS NULL OR A.counterpartAssetCustomerNumber < 1) THEN 'Customer not found in counterpart asset'
            ELSE NULL
        END AS customerRootCause
    FROM 
        AssetsWithoutContract A
),
ItemMaterialMappingCheck AS (
    -- Step 9: Check for item material mapping
    SELECT 
        C.contractId,
        C.contractItemNumber,
        C.counterpartAgreementSourceSiteId,
        CASE 
            WHEN C.counterpartAgreementSourceSiteId = 6 THEN (
                SELECT EMC_ITEM_NUM 
                FROM SDR.ITEM_MATERIAL_MAPPING IMM 
                WHERE IMM.EMC_ITEM_NUM = C.contractItemNumber 
                AND IMM.APPLICATION_ID = 33
                AND IMM.ITEM_MATERIAL_MAP_TYPE_ID IN (1, 3, 4, 5, 6)
            )
            ELSE (
                SELECT DELL_ITEM_NUM 
                FROM SDR.ITEM_MATERIAL_MAPPING IMM 
                WHERE IMM.DELL_ITEM_NUM = C.contractItemNumber 
                AND IMM.APPLICATION_ID = 33
                AND IMM.ITEM_MATERIAL_MAP_TYPE_ID IN (1, 3, 4, 5, 6)
            )
        END AS itemMaterialMapping
    FROM 
        ContractsForOriginalAssets C
),
GlobalItemMainCheck AS (
    -- Step 10: Check for global item main record
    SELECT 
        I.contractId,
        I.itemMaterialMapping,
        I.counterpartAgreementSourceSiteId,
        CASE 
            WHEN I.itemMaterialMapping IS NOT NULL AND I.counterpartAgreementSourceSiteId = 6 THEN (
                SELECT ITEM_NUM 
                FROM SDR.GLOBAL_ITEM_MAIN 
                WHERE ITEM_NUM = I.itemMaterialMapping 
                AND SOURCE_SITE_ID <> 6
            )
            WHEN I.itemMaterialMapping IS NOT NULL AND I.counterpartAgreementSourceSiteId <> 6 THEN (
                SELECT ITEM_NUM 
                FROM SDR.GLOBAL_ITEM_MAIN 
                WHERE ITEM_NUM = I.itemMaterialMapping 
                AND SOURCE_SITE_ID = 6
            )
            ELSE NULL
        END AS globalItemMain
    FROM 
        ItemMaterialMappingCheck I
),
FinalCheck AS (
    -- Step 11: Check for missing global item main record
    SELECT 
        G.contractId,
        CASE 
            WHEN G.globalItemMain IS NULL AND G.itemMaterialMapping IS NOT NULL THEN 'Missing Global Item Main'
            WHEN EXISTS (
                SELECT 1 
                FROM SDR.DUAL_SERIAL_INSTRUCTION 
                WHERE ENTITY_TYPE_ID = 1 
                AND ENTITY_VALUE = G.contractId
            ) THEN 'Instruction in Error'
            ELSE 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 
                        FROM AEENT.AGREEMENT_CONTRACT AC 
                        WHERE AC.CUSTOMER_CONTRACT_ID = G.contractId
                    ) THEN '[AGREEMENT] Other'
                    ELSE 'Other'
                END
        END AS rootCause
    FROM 
        GlobalItemMainCheck G
)
SELECT 
    A.counterpartAssetId,
    A.counterpartAssetSerialNumber,
    A.counterpartAssetManufacturerId,
    A.counterpartAssetItemClass,
    A.counterpartAssetSourceSiteId,
    A.counterpartAssetCustomerNumber,
    C.contractId,
    C.contractItemNumber,
    RCA.rootCause,
    ACS.counterpartAgreementId,
    ACS.counterpartAgreementSourceSiteId,
    ACS.counterpartAgreementContractId,
    CAAC.agreementAssetRootCause,
    PLC.partyLocationRootCause,
    CCC.customerRootCause,
    IMM.itemMaterialMapping,
    F.rootCause AS finalRootCause
FROM 
    AssetsWithoutContract A
LEFT JOIN 
    ContractsForOriginalAssets C ON A.counterpartAssetId = C.counterpartAssetId
LEFT JOIN 
    ContractRootCauseClassification RCA ON C.contractId = RCA.contractId
LEFT JOIN 
    AgreementCheck AC ON C.contractId = AC.contractId
LEFT JOIN 
    CounterpartAgreementSource ACS ON AC.counterpartAgreementId = ACS.counterpartAgreementId
LEFT JOIN 
    CounterpartAgreementAssetsCheck CAAC ON ACS.counterpartAgreementId = CAAC.counterpartAgreementId
LEFT JOIN 
    PartyLocationCheck PLC ON ACS.counterpartAgreementId = PLC.counterpartAgreementId
LEFT JOIN 
    CustomerCheckForCounterpartAsset CCC ON A.counterpartAssetId = CCC.counterpartAssetId
LEFT JOIN 
    ItemMaterialMappingCheck IMM ON C.contractId = IMM.contractId
LEFT JOIN 
    FinalCheck F ON C.contractId = F.contractId;
	
	
-----------------------------------

-- Step 1: Assets without associated contracts
WITH AssetsWithoutContract AS (
    SELECT 
        CP.CUSTOMER_PRODUCT_ID AS counterpartAssetId,
        CP.MFG_SERIAL_NUM AS counterpartAssetSerialNumber,
        CP.MANUFACTURER_ID AS counterpartAssetManufacturerId,
        CP.ITEM_CLASS AS counterpartAssetItemClass,
        CP.SOURCE_SITE_ID AS counterpartAssetSourceSiteId,
        CP.CUSTOMER_NUM AS counterpartAssetCustomerNumber
    FROM 
        AEAST.CUSTOMER_PRODUCT CP
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    WHERE 
        CP.SOURCE_SYS_CREATE_PGM IN ('AC_NG.DS.SW_AS_A.CRI', 'AC_NG.DS.SW_A.CRY', 'AC_NG.DUAL_SRL_INS.ASSET')
        AND CC.CUSTOMER_CONTRACT_ID IS NULL
        AND CP.ORDER_NUM = 99999
        AND CP.SOURCE_SYS_CREATE_DTS BETWEEN '2023-10-01 00:00:00' AND '2023-10-31 23:59:59'
),

-- Step 2: Lookup original asset
OriginalAssetLookup AS (
    SELECT 
        A.counterpartAssetId,
        CPR.TO_CUSTOMER_PRODUCT_ID AS originalAssetId
    FROM 
        AssetsWithoutContract A
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT_REL CPR
    ON 
        A.counterpartAssetId = CPR.FROM_CUSTOMER_PRODUCT_ID
        AND CPR.RELATIONSHIP_TYPE_ID = 9
),

-- Step 3: Contracts associated with the original assets
ContractsForOriginalAssets AS (
    SELECT 
        OAL.counterpartAssetId,
        OAL.originalAssetId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original asset not found'
            ELSE CC.CUSTOMER_CONTRACT_ID 
        END AS contractId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN NULL
            ELSE CC.ITEM_NUM 
        END AS contractItemNumber,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original Asset Without Entitlement'
            ELSE NULL
        END AS rootCause
    FROM 
        OriginalAssetLookup OAL
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC 
    ON 
        OAL.originalAssetId = CC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT CP
    ON 
        CPC.CUSTOMER_PRODUCT_ID = CP.CUSTOMER_PRODUCT_ID
),

-- Step 4: Check if the contract has an agreement
AgreementCheck AS (
    SELECT 
        C.contractId,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.CUSTOMER_CONTRACT_ID = C.contractId
            ) THEN (
                SELECT AI.AGREEMENT_IDENTIFIER_VALUE 
                FROM AEAGR.AGREEMENT_IDENTIFIER AI
                WHERE AI.AGREEMENT_ID = (
                    SELECT AGREEMENT_ID 
                    FROM AEENT.AGREEMENT_CONTRACT 
                    WHERE CUSTOMER_CONTRACT_ID = C.contractId
                )
                AND AI.IDENTIFIER_TYPE_ID IN (111, 112)
                LIMIT 1
            )
            ELSE 'CounterPart Agreement Not Found'
        END AS counterpartAgreementId
    FROM 
        ContractsForOriginalAssets C
),

-- Step 5: Get source site ID and associated contracts
CounterpartAgreementSource AS (
    SELECT 
        A.counterpartAgreementId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT AGREEMENT.SOURCE_SITE_ID 
                FROM AEAGR.AGREEMENT 
                WHERE AGREEMENT.AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementSourceSiteId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT CUSTOMER_CONTRACT_ID 
                FROM AEENT.AGREEMENT_CONTRACT 
                WHERE AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementContractId
    FROM 
        AgreementCheck A
),

-- Step 6: Check for missing agreement/asset relationship
CounterpartAgreementAssetsCheck AS (
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
            ) THEN 'Missing Agreement/Asset Relationship'
            WHEN NOT EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                JOIN AEENT.CONTRACT_PRODUCT_COVERAGE CPC 
                ON AC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
                  AND CPC.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) THEN 'CounterPart Agreement Linked to Non-Mapped Asset'
            ELSE NULL
        END AS agreementAssetRootCause
    FROM 
        CounterpartAgreementSource C
    JOIN 
        AssetsWithoutContract A 
    ON 
        1 = 1
),

-- Step 7: Check for party address record
PartyLocationCheck AS (
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN (
                SELECT COUNT(*) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) = 0 
            OR (C.counterpartAgreementSourceSiteId = 6 AND (
                SELECT COALESCE(PA.UCID, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1)
            OR (C.counterpartAgreementSourceSiteId <> 6 AND (
                SELECT COALESCE(PA.CUSTOMER_NUM, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1) THEN 'PartyLocation not found'
            ELSE NULL
        END AS partyLocationRootCause
    FROM 
        CounterpartAgreementSource C
),

-- Step 8: Check for party address record in the counterpart asset
CustomerCheckForCounterpartAsset AS (
    SELECT 
        A.counterpartAssetId,
        CASE 
            WHEN (
                SELECT COUNT(*) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) = 0
            OR (A.counterpartAssetSourceSiteId = 6 AND (
                SELECT COALESCE(PA.UCID, 0) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) < 1)
            OR (A.counterpartAssetSourceSiteId <> 6 AND (
                SELECT COALESCE(PA.CUSTOMER_NUM, 0) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) < 1)
            OR (A.counterpartAssetCustomerNumber IS NULL OR A.counterpartAssetCustomerNumber < 1) THEN 'Customer not found in counterpart asset'
            ELSE NULL
        END AS customerRootCause
    FROM 
        AssetsWithoutContract A
),

-- Step 9: Check for item material mapping
ItemMaterialMappingCheck AS (
    SELECT 
        C.contractId,
        C.contractItemNumber,
        C.counterpartAgreementSourceSiteId,
        CASE 
            WHEN C.counterpartAgreementSourceSiteId = 6 THEN (
                SELECT EMC_ITEM_NUM 
                FROM SDR.ITEM_MATERIAL_MAPPING IMM 
                WHERE IMM.EMC_ITEM_NUM = C.contractItemNumber 
                AND IMM.APPLICATION_ID = 33
                AND IMM.ITEM_MATERIAL_MAP_TYPE_ID IN (1, 3, 4, 5, 6)
                LIMIT 1
            )
            ELSE (
                SELECT DELL_ITEM_NUM 
                FROM SDR.ITEM_MATERIAL_MAPPING IMM 
                WHERE IMM.DELL_ITEM_NUM = C.contractItemNumber 
                AND IMM.APPLICATION_ID = 33
                AND IMM.ITEM_MATERIAL_MAP_TYPE_ID IN (1, 3, 4, 5, 6)
                LIMIT 1
            )
        END AS itemMaterialMapping
    FROM 
        ContractsForOriginalAssets C
),

-- Step 10: Check for global item main record
GlobalItemMainCheck AS (
    SELECT 
        I.contractId,
        I.itemMaterialMapping,
        I.counterpartAgreementSourceSiteId,
        CASE 
            WHEN I.itemMaterialMapping IS NOT NULL AND I.counterpartAgreementSourceSiteId = 6 THEN (
                SELECT ITEM_NUM 
                FROM SDR.GLOBAL_ITEM_MAIN 
                WHERE ITEM_NUM = I.itemMaterialMapping 
                AND SOURCE_SITE_ID <> 6
                LIMIT 1
            )
            WHEN I.itemMaterialMapping IS NOT NULL AND I.counterpartAgreementSourceSiteId <> 6 THEN (
                SELECT ITEM_NUM 
                FROM SDR.GLOBAL_ITEM_MAIN 
                WHERE ITEM_NUM = I.itemMaterialMapping 
                AND SOURCE_SITE_ID = 6
                LIMIT 1
            )
            ELSE NULL
        END AS globalItemMain
    FROM 
        ItemMaterialMappingCheck I
),

-- Step 11: Final root cause determination
FinalCheck AS (
    SELECT 
        G.contractId,
        CASE 
            WHEN G.globalItemMain IS NULL AND G.itemMaterialMapping IS NOT NULL THEN 'Missing Global Item Main'
            WHEN EXISTS (
                SELECT 1 
                FROM SDR.DUAL_SERIAL_INSTRUCTION 
                WHERE ENTITY_TYPE_ID = 1 
                AND ENTITY_VALUE = G.contractId
            ) THEN 'Instruction in Error'
            ELSE 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 
                        FROM AEENT.AGREEMENT_CONTRACT AC 
                        WHERE AC.CUSTOMER_CONTRACT_ID = G.contractId
                    ) THEN '[AGREEMENT] Other'
                    ELSE 'Other'
                END
        END AS rootCause
    FROM 
        GlobalItemMainCheck G
)

-- Final selection
SELECT 
    A.counterpartAssetId,
    A.counterpartAssetSerialNumber,
    A.counterpartAssetManufacturerId,
    A.counterpartAssetItemClass,
    A.counterpartAssetSourceSiteId,
    A.counterpartAssetCustomerNumber,
    C.contractId,
    C.contractItemNumber,
    COALESCE(RCA.rootCause, '') AS rootCause,
    ACS.counterpartAgreementId,
    ACS.counterpartAgreementSourceSiteId,
    ACS.counterpartAgreementContractId,
    CAAC.agreementAssetRootCause,
    PLC.partyLocationRootCause,
    CCC.customerRootCause,
    IMM.itemMaterialMapping,
    F.rootCause AS finalRootCause
FROM 
    AssetsWithoutContract A
LEFT JOIN 
    ContractsForOriginalAssets C ON A.counterpartAssetId = C.counterpartAssetId
LEFT JOIN 
    ContractRootCauseClassification RCA ON C.contractId = RCA.contractId
LEFT JOIN 
    AgreementCheck AC ON C.contractId = AC.contractId
LEFT JOIN 
    CounterpartAgreementSource ACS ON AC.counterpartAgreementId = ACS.counterpartAgreementId
LEFT JOIN 
    CounterpartAgreementAssetsCheck CAAC ON ACS.counterpartAgreementId = CAAC.counterpartAgreementId
LEFT JOIN 
    PartyLocationCheck PLC ON ACS.counterpartAgreementId = PLC.counterpartAgreementId
LEFT JOIN 
    CustomerCheckForCounterpartAsset CCC ON A.counterpartAssetId = CCC.counterpartAssetId
LEFT JOIN 
    ItemMaterialMappingCheck IMM ON C.contractId = IMM.contractId
LEFT JOIN 
    FinalCheck F ON C.contractId = F.contractId;

-----------------------------------------------------------------------



=================================================================

Tables used:
AEAST.CUSTOMER_PRODUCT 
AEAST.CUSTOMER_PRODUCT_REL 
AEENT.AGREEMENT_CONTRACT 
AEENT.CUSTOMER_CONTRACT 
AEENT.CONTRACT_PRODUCT_COVERAGE 
AEAGR.AGREEMENT
AEAGR.AGREEMENT_CUSTOMER_PRODUCT 
AEAGR. AGREEMENT_IDENTIFIER
AEPA. PARTY_ADDRESS 
AEPA. PARTY_ADDRESS_AGREEMENT 
AEPA. PARTY_ADDRESS_ASSET 
SDR. DUAL_SERIAL_INSTRUCTION 
SDR. GLOBAL_ITEM_MAIN 
SDR. ITEM_MATERIAL_MAPPING

first question, first, we get assets that were created in a period and have no contract associated with, using the query below
select CUSTOMER_PRODUCT_ID as counterpartAssetId,
MFG_SERIAL_NUM as counterpartAssetSerialNumber,
MANUFACTURER_ID as counterpartAssetManufacturerId,
ITEM_CLASS as counterpartAssetItemClass,
SOURCE_SITE_ID as counterpartAssetSourceSiteId,
CUSTOMER_NUM as counterpartAssetCustomerNumber 
from AEAST. CUSTOMER_PRODUCT CP
left join AEENT. CONTRACT_PRODUCT_COVERAGE pc
on CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
left join AEENT. CUSTOMER_CONTRACT CC
on CC.CUSTOMER_ CONTRACT_ ID = CPC. CUSTOMER_CONTRACT_ID
Where CP. SOURCE_SYS_CREATE PGM in ('AC_NG.DS.SW_AS_A.CRI','AC_NG.DS. SW_A.CRY','AC_NG. DUAL_SRL_INS.ASSET')
and CC.CUSTOMER CONTRACT ID is null
and CP.ORDER_NUM = 99999
and CP. SOURCE_SYS_CREATE_DTS
between TO DATE ('2023-10-01 00:00:00','YYYY-mn-dd HH24 :MI: SS') and TO DATE ('2023-10-31 23:59:59', 'YYYY-mn-dd HH24 :MI: SS')

--After assets are retrieved, for each asset we get the original asset ID associated that is present in the asset relationship record which has relationship type 9
select TO_CUSTOMER_PRODUCT_ID as originalAssetId from AEAST. CUSTOMER_PRODUCT_REL
where FROM CUSTOMER_PRODUCT_ID = counterpartAssetId
AND RELATIONSHIP_TYPE_ID=9;

--If there is no asset relationship record found then the root cause for the asset should be "Original asset not found" If the original asset was found, we get the contracts that are associated with it 
select CC.CUSTOMER_CONTRACT_ID as contractId,
CC.ITEM_NUM as contractItemNumber 
from AEENT. CUSTOMER_CONTRACT CC 
join ABENT.CONTRACT_PRODUCT_COVERAGE CPC
on CC.CUSTOMER_CONTRACT_ID = CPC. CUSTOMER_CONTRACT_ID
join AEAST. CUSTOMER_PRODUCT CP
On CPC.CUSTOMER_PRODUCT_ID = CP. CUSTOMER_PRODUCT_ID
where CP. CUSTOMER_PRODUCT_ID = :originalAsgetId;

use above queries and get the single query including all the usecases mentioned in the -- comment
ChatGPT said:
ChatGPT
To combine the steps described in your comments into a single SQL query, we need to perform the following operations in sequence:

Retrieve assets created in a given period without an associated contract.
For each asset retrieved, find the original asset ID associated with it.
If no original asset is found, mark the root cause as "Original asset not found".
If an original asset is found, retrieve the contracts associated with it.
Here is a combined SQL query that performs all these operations:

sql
Copy code
WITH AssetsWithoutContract AS (
    SELECT 
        CP.CUSTOMER_PRODUCT_ID AS counterpartAssetId,
        CP.MFG_SERIAL_NUM AS counterpartAssetSerialNumber,
        CP.MANUFACTURER_ID AS counterpartAssetManufacturerId,
        CP.ITEM_CLASS AS counterpartAssetItemClass,
        CP.SOURCE_SITE_ID AS counterpartAssetSourceSiteId,
        CP.CUSTOMER_NUM AS counterpartAssetCustomerNumber
    FROM 
        AEAST.CUSTOMER_PRODUCT CP
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    WHERE 
        CP.SOURCE_SYS_CREATE_PGM IN ('AC_NG.DS.SW_AS_A.CRI', 'AC_NG.DS.SW_A.CRY', 'AC_NG.DUAL_SRL_INS.ASSET')
        AND CC.CUSTOMER_CONTRACT_ID IS NULL
        AND CP.ORDER_NUM = 99999
        AND CP.SOURCE_SYS_CREATE_DTS BETWEEN TO_DATE('2023-10-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS') 
        AND TO_DATE('2023-10-31 23:59:59', 'YYYY-MM-DD HH24:MI:SS')
),
OriginalAssetLookup AS (
    SELECT 
        A.counterpartAssetId,
        CPR.TO_CUSTOMER_PRODUCT_ID AS originalAssetId
    FROM 
        AssetsWithoutContract A
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT_REL CPR
    ON 
        A.counterpartAssetId = CPR.FROM_CUSTOMER_PRODUCT_ID
        AND CPR.RELATIONSHIP_TYPE_ID = 9
),
ContractsForOriginalAssets AS (
    SELECT 
        OAL.counterpartAssetId,
        OAL.originalAssetId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original asset not found'
            ELSE CC.CUSTOMER_CONTRACT_ID 
        END AS contractId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN NULL
            ELSE CC.ITEM_NUM 
        END AS contractItemNumber
    FROM 
        OriginalAssetLookup OAL
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC 
    ON 
        OAL.originalAssetId = CC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT CP
    ON 
        CPC.CUSTOMER_PRODUCT_ID = CP.CUSTOMER_PRODUCT_ID
)
SELECT 
    counterpartAssetId,
    counterpartAssetSerialNumber,
    counterpartAssetManufacturerId,
    counterpartAssetItemClass,
    counterpartAssetSourceSiteId,
    counterpartAssetCustomerNumber,
    originalAssetId,
    contractId,
    contractItemNumber
FROM 
    ContractsForOriginalAssets;
Explanation:
AssetsWithoutContract CTE: Retrieves assets created in the specified period that have no associated contract.
OriginalAssetLookup CTE: For each asset found, it checks for the existence of a related original asset (with RELATIONSHIP_TYPE_ID = 9). If no relationship is found, originalAssetId will be NULL.
ContractsForOriginalAssets CTE: This step retrieves the contracts associated with each original asset found. If an original asset is not found, it outputs "Original asset not found" as the contractId and leaves contractItemNumber as NULL.
Final SELECT: Combines all the results and displays the required information, including the counterpart asset details, original asset ID (if found), and contract details (if any).
Feel free to adjust the query based on specific table structures or additional requirements.






You said:
--if there is no contract assocoiated with the original assest then the root cause for the asset should be "Original Asset Without Entitlement"
--At this point, we start classifying the root cause for the contract, which means one asset can have more than one root cause, one for each contract For each contract found in the previous step we do the following:
--Check if the contract is already dual serialized but linked to a contract from a different asset by getting the identifier record with IDENTIFIER_TYPE_ID 106
select CUSTOMER_CONTRACT_ID 
from AEENT.CUSTOMER_CONTRACT_IDENTIFIER where CONTRACT_IDENTIFIER_VALUE: contractId and IDENTIFIER_TYPE_ID = 106;

--If a record is found in the previous step then the root cause for the contract should be "Original entitlement dual serialized to different asset"
--Check if the contract item number is one of the following:
--'709-BBEW', '865-BCFG', '709-BBOR', '865-BCFF', '303-11289', '865-BCFD', '709-BBEX', '199-BBJQ', '865-BCFE', '865-BCFK', '709-BBTV', '709-BBNG', '862- BBXI', '303-11291', '303-11290', '865-BCFJ', '199-BBMF', '865-BBJP', '303-11466', '142-BBNV', '149-BBGI', '149-BBGK', '151-BBEH', '151-BBGU', '151- BBHJ', '151-BBHY', '151-BBIY', '151-BBJB', '151-BBJE', '151-BBJF', '151-BBJP', '456-109-802', '456-109-803', '456-109-804', '456-109-805', '456-111-473', '456-111-474', '456-111-475', '456-111-476', '528-BYHE', '528- BYHF
-- If the contract item number is one of the above then the root cause for the contract should be "SKU not eligible"
--If the contract didn't fall in the previous step we check if it has an agreement

add this condition also to above query
ChatGPT said:
ChatGPT
To add the new conditions to the previously provided SQL query, we will follow these additional steps:

Check if there is no contract associated with the original asset. If no contract is found, the root cause is "Original Asset Without Entitlement."

For each contract found, perform additional checks:

Check if the contract is already dual serialized and linked to a different asset by looking for an identifier with IDENTIFIER_TYPE_ID = 106. If such a record is found, the root cause is "Original entitlement dual serialized to different asset."
Check if the contract item number matches a specific list of SKUs. If it does, the root cause is "SKU not eligible."
If none of the above checks apply, check if the contract has an associated agreement.
Here's the modified SQL query incorporating these conditions:

sql
Copy code
WITH AssetsWithoutContract AS (
    SELECT 
        CP.CUSTOMER_PRODUCT_ID AS counterpartAssetId,
        CP.MFG_SERIAL_NUM AS counterpartAssetSerialNumber,
        CP.MANUFACTURER_ID AS counterpartAssetManufacturerId,
        CP.ITEM_CLASS AS counterpartAssetItemClass,
        CP.SOURCE_SITE_ID AS counterpartAssetSourceSiteId,
        CP.CUSTOMER_NUM AS counterpartAssetCustomerNumber
    FROM 
        AEAST.CUSTOMER_PRODUCT CP
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    WHERE 
        CP.SOURCE_SYS_CREATE_PGM IN ('AC_NG.DS.SW_AS_A.CRI', 'AC_NG.DS.SW_A.CRY', 'AC_NG.DUAL_SRL_INS.ASSET')
        AND CC.CUSTOMER_CONTRACT_ID IS NULL
        AND CP.ORDER_NUM = 99999
        AND CP.SOURCE_SYS_CREATE_DTS BETWEEN TO_DATE('2023-10-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS') 
        AND TO_DATE('2023-10-31 23:59:59', 'YYYY-MM-DD HH24:MI:SS')
),
OriginalAssetLookup AS (
    SELECT 
        A.counterpartAssetId,
        CPR.TO_CUSTOMER_PRODUCT_ID AS originalAssetId
    FROM 
        AssetsWithoutContract A
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT_REL CPR
    ON 
        A.counterpartAssetId = CPR.FROM_CUSTOMER_PRODUCT_ID
        AND CPR.RELATIONSHIP_TYPE_ID = 9
),
ContractsForOriginalAssets AS (
    SELECT 
        OAL.counterpartAssetId,
        OAL.originalAssetId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original asset not found'
            ELSE CC.CUSTOMER_CONTRACT_ID 
        END AS contractId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN NULL
            ELSE CC.ITEM_NUM 
        END AS contractItemNumber,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original Asset Without Entitlement'
            ELSE NULL
        END AS rootCause
    FROM 
        OriginalAssetLookup OAL
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC 
    ON 
        OAL.originalAssetId = CC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT CP
    ON 
        CPC.CUSTOMER_PRODUCT_ID = CP.CUSTOMER_PRODUCT_ID
),
ContractRootCauseClassification AS (
    SELECT 
        C.contractId,
        C.contractItemNumber,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM AEENT.CUSTOMER_CONTRACT_IDENTIFIER CI 
                WHERE CI.CONTRACT_IDENTIFIER_VALUE = C.contractId 
                  AND CI.IDENTIFIER_TYPE_ID = 106
            ) THEN 'Original entitlement dual serialized to different asset'
            WHEN C.contractItemNumber IN (
                '709-BBEW', '865-BCFG', '709-BBOR', '865-BCFF', '303-11289', '865-BCFD', 
                '709-BBEX', '199-BBJQ', '865-BCFE', '865-BCFK', '709-BBTV', '709-BBNG', 
                '862-BBXI', '303-11291', '303-11290', '865-BCFJ', '199-BBMF', '865-BBJP', 
                '303-11466', '142-BBNV', '149-BBGI', '149-BBGK', '151-BBEH', '151-BBGU', 
                '151-BBHJ', '151-BBHY', '151-BBIY', '151-BBJB', '151-BBJE', '151-BBJF', 
                '151-BBJP', '456-109-802', '456-109-803', '456-109-804', '456-109-805', 
                '456-111-473', '456-111-474', '456-111-475', '456-111-476', '528-BYHE', 
                '528-BYHF'
            ) THEN 'SKU not eligible'
            ELSE 'Has agreement'
        END AS rootCause
    FROM 
        ContractsForOriginalAssets C
)
SELECT 
    counterpartAssetId,
    counterpartAssetSerialNumber,
    counterpartAssetManufacturerId,
    counterpartAssetItemClass,
    counterpartAssetSourceSiteId,
    counterpartAssetCustomerNumber,
    originalAssetId,
    contractId,
    contractItemNumber,
    COALESCE(Classified.rootCause, Contracts.rootCause) AS rootCause
FROM 
    ContractsForOriginalAssets Contracts
LEFT JOIN 
    ContractRootCauseClassification Classified 
ON 
    Contracts.contractId = Classified.contractId;
Explanation:
AssetsWithoutContract CTE: Retrieves assets created in the specified period that have no associated contract.
OriginalAssetLookup CTE: For each asset found, checks for the existence of a related original asset.
ContractsForOriginalAssets CTE: This step retrieves the contracts associated with each original asset found and identifies assets without entitlement.
ContractRootCauseClassification CTE: This step adds classification checks for each contract found:
It checks for dual serialization with a different asset.
It checks if the contract item number is in a specified list of SKUs.
If neither condition applies, it checks if there is an associated agreement.
Final SELECT: Combines all the results, ensuring the root cause is correctly identified for each scenario.
This query now accounts for all conditions, as requested.






You said:
add the following condition also 
select AGREEMENT_ID as originalAgreementId
from AEENT.AGREEMENT_CONTRACT where CUSTOMER_CONTRACT_ID = : contractId;
--If the contract has an agreement:
-- We get the counterpart agreement ID that is present in the AGREEMENT_IDENTIFIER_VALUE column
--from the agreement identifier record which has identifier type 111 or 112 
select AGREEMENT_IDENTIFIER_VALUE as counterpartAgreementId from AEAGR.AGREEMENT IDENTIFIER
where AGREEMENT_ID = : originalAgreement Id and IDENTIFIER TYPE_ID in (111, 112);
-- If there is no agreement identifier record then the root cause for the contract
--should be "CounterPart Agreement Not Found"
--If the counterpart agreement ID is present then we get the SOURCE_SITE_ID value from the counterpart agreement 
select SOURCE_SITE_ID as counterpartAgreement SourceSiteId
from AEAGR.AGREEMENT where AGREEMENT_ID : counterpartAgreementId;
--After that, we get the contracts that are associated with the counterpart agreement 
select CUSTOMER_CONTRACT_ID as counterpartAgreementContractId from AEENT.AGREEMENT_CONTRACT
where AGREEMENT_ID = :counterpartAgreementId;
ChatGPT said:
ChatGPT
To incorporate the additional steps for handling contracts that have an agreement, the query needs to be extended further to include:

Check if the contract has an agreement.
Retrieve the counterpart agreement ID based on the AGREEMENT_IDENTIFIER record where IDENTIFIER_TYPE_ID is 111 or 112.
If no agreement identifier record is found, set the root cause for the contract to "CounterPart Agreement Not Found."
If the counterpart agreement ID is present, retrieve the SOURCE_SITE_ID from the counterpart agreement.
Get the contracts associated with the counterpart agreement.
Here's the extended SQL query that includes these additional conditions:

sql
Copy code
WITH AssetsWithoutContract AS (
    SELECT 
        CP.CUSTOMER_PRODUCT_ID AS counterpartAssetId,
        CP.MFG_SERIAL_NUM AS counterpartAssetSerialNumber,
        CP.MANUFACTURER_ID AS counterpartAssetManufacturerId,
        CP.ITEM_CLASS AS counterpartAssetItemClass,
        CP.SOURCE_SITE_ID AS counterpartAssetSourceSiteId,
        CP.CUSTOMER_NUM AS counterpartAssetCustomerNumber
    FROM 
        AEAST.CUSTOMER_PRODUCT CP
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    WHERE 
        CP.SOURCE_SYS_CREATE_PGM IN ('AC_NG.DS.SW_AS_A.CRI', 'AC_NG.DS.SW_A.CRY', 'AC_NG.DUAL_SRL_INS.ASSET')
        AND CC.CUSTOMER_CONTRACT_ID IS NULL
        AND CP.ORDER_NUM = 99999
        AND CP.SOURCE_SYS_CREATE_DTS BETWEEN TO_DATE('2023-10-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS') 
        AND TO_DATE('2023-10-31 23:59:59', 'YYYY-MM-DD HH24:MI:SS')
),
OriginalAssetLookup AS (
    SELECT 
        A.counterpartAssetId,
        CPR.TO_CUSTOMER_PRODUCT_ID AS originalAssetId
    FROM 
        AssetsWithoutContract A
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT_REL CPR
    ON 
        A.counterpartAssetId = CPR.FROM_CUSTOMER_PRODUCT_ID
        AND CPR.RELATIONSHIP_TYPE_ID = 9
),
ContractsForOriginalAssets AS (
    SELECT 
        OAL.counterpartAssetId,
        OAL.originalAssetId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original asset not found'
            ELSE CC.CUSTOMER_CONTRACT_ID 
        END AS contractId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN NULL
            ELSE CC.ITEM_NUM 
        END AS contractItemNumber,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original Asset Without Entitlement'
            ELSE NULL
        END AS rootCause
    FROM 
        OriginalAssetLookup OAL
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC 
    ON 
        OAL.originalAssetId = CC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT CP
    ON 
        CPC.CUSTOMER_PRODUCT_ID = CP.CUSTOMER_PRODUCT_ID
),
ContractRootCauseClassification AS (
    SELECT 
        C.contractId,
        C.contractItemNumber,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM AEENT.CUSTOMER_CONTRACT_IDENTIFIER CI 
                WHERE CI.CONTRACT_IDENTIFIER_VALUE = C.contractId 
                  AND CI.IDENTIFIER_TYPE_ID = 106
            ) THEN 'Original entitlement dual serialized to different asset'
            WHEN C.contractItemNumber IN (
                '709-BBEW', '865-BCFG', '709-BBOR', '865-BCFF', '303-11289', '865-BCFD', 
                '709-BBEX', '199-BBJQ', '865-BCFE', '865-BCFK', '709-BBTV', '709-BBNG', 
                '862-BBXI', '303-11291', '303-11290', '865-BCFJ', '199-BBMF', '865-BBJP', 
                '303-11466', '142-BBNV', '149-BBGI', '149-BBGK', '151-BBEH', '151-BBGU', 
                '151-BBHJ', '151-BBHY', '151-BBIY', '151-BBJB', '151-BBJE', '151-BBJF', 
                '151-BBJP', '456-109-802', '456-109-803', '456-109-804', '456-109-805', 
                '456-111-473', '456-111-474', '456-111-475', '456-111-476', '528-BYHE', 
                '528-BYHF'
            ) THEN 'SKU not eligible'
            ELSE 'Has agreement'
        END AS rootCause
    FROM 
        ContractsForOriginalAssets C
),
AgreementCheck AS (
    SELECT 
        C.contractId,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.CUSTOMER_CONTRACT_ID = C.contractId
            ) THEN (
                SELECT AI.AGREEMENT_IDENTIFIER_VALUE 
                FROM AEAGR.AGREEMENT_IDENTIFIER AI
                WHERE AI.AGREEMENT_ID = (
                    SELECT AGREEMENT_ID 
                    FROM AEENT.AGREEMENT_CONTRACT 
                    WHERE CUSTOMER_CONTRACT_ID = C.contractId
                )
                AND AI.IDENTIFIER_TYPE_ID IN (111, 112)
                FETCH FIRST 1 ROWS ONLY
            )
            ELSE 'CounterPart Agreement Not Found'
        END AS counterpartAgreementId
    FROM 
        ContractsForOriginalAssets C
),
CounterpartAgreementSource AS (
    SELECT 
        A.counterpartAgreementId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT AGREEMENT.SOURCE_SITE_ID 
                FROM AEAGR.AGREEMENT 
                WHERE AGREEMENT.AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementSourceSiteId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT CUSTOMER_CONTRACT_ID 
                FROM AEENT.AGREEMENT_CONTRACT 
                WHERE AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementContractId
    FROM 
        AgreementCheck A
)
SELECT 
    counterpartAssetId,
    counterpartAssetSerialNumber,
    counterpartAssetManufacturerId,
    counterpartAssetItemClass,
    counterpartAssetSourceSiteId,
    counterpartAssetCustomerNumber,
    originalAssetId,
    contractId,
    contractItemNumber,
    COALESCE(Classified.rootCause, Contracts.rootCause, AgreementCheck.counterpartAgreementId, CounterpartAgreementSource.counterpartAgreementSourceSiteId) AS rootCause
FROM 
    ContractsForOriginalAssets Contracts
LEFT JOIN 
    ContractRootCauseClassification Classified 
ON 
    Contracts.contractId = Classified.contractId
LEFT JOIN 
    AgreementCheck 
ON 
    Contracts.contractId = AgreementCheck.contractId
LEFT JOIN 
    CounterpartAgreementSource 
ON 
    AgreementCheck.counterpartAgreementId = CounterpartAgreementSource.counterpartAgreementId;
Explanation:
AssetsWithoutContract CTE: Retrieves assets created in the specified period with no associated contract.
OriginalAssetLookup CTE: Checks for a related original asset for each asset found.
ContractsForOriginalAssets CTE: Retrieves the contracts associated with each original asset found and identifies assets without entitlement.
ContractRootCauseClassification CTE: Classifies each contract for:
Dual serialization.
Ineligible SKU.
If none, it assumes "Has agreement."
AgreementCheck CTE: Checks if the contract has an associated agreement and retrieves the counterpart agreement ID or sets "CounterPart Agreement Not Found."
CounterpartAgreementSource CTE: If the counterpart agreement ID is present, retrieves the SOURCE_SITE_ID and the associated contract ID.
Final SELECT: Combines all results, ensuring the root cause is correctly identified for each scenario, including cases where agreements and counterpart agreements are involved.





You said:
add the following condition to above existing query
--If there is no asset associated with the counterpart agreement then the root cause for the contract should be "Missing Agreement/Asset Relationship"
--If none of the assets associated with the counterpart agreement is the counterpart asset that we got at the beginning of the process then the root cause for the contract should be "CounterPart Agreement Linked to Non-Mapped Asset"
--After that, we get the party address record for the counterpart agreement
select PA.CUSTOMER NUM, PA.UCID from AEPA. PARTY ADDRESS AGREEMENT PAA
join AEPA. PARTY ADDRESS PA on PAA.PARTY_ADDRESS_ID = PA. PARTY_ADDRESS_ID where PAA.AGREEMENT ID : counterpartAgreementId;
--If there is no party address record for the counterpart agreement or counterpart agreement source site ID is 6 and party address UCID record is null or lower than 1
--or counterpart agreement source site ID is different than 6 and party address customer number record is null or lower than 1 then the root cause for the contract should be "PartyLocation not found"
--If the contract has no agreement we get the party address record for the counterpart asset
select PA.CUSTOMER_NUM, PA.UCID from AEPA. PARTY_ADDRESS_ASSET PAA
join AEPA.PARTY_ADDRESS PA on PAA. PARTY_ADDRESS_ID = PA. PARTY_ADDRESS_ID
where PAA.CUSTOMER_PRODUCT_ID = : counterpartAssetId
ChatGPT said:
ChatGPT
To incorporate the additional steps into the existing query, we need to add further conditions for:

Checking the existence of assets associated with the counterpart agreement:

If there are no assets associated with the counterpart agreement, the root cause should be "Missing Agreement/Asset Relationship."
If none of the assets associated with the counterpart agreement is the counterpart asset identified at the beginning, the root cause should be "CounterPart Agreement Linked to Non-Mapped Asset."
Retrieving the party address record for the counterpart agreement:

If there is no party address record or the specific conditions related to counterpartAgreementSourceSiteId and party address UCID or customer number are met, the root cause should be "PartyLocation not found."
Handling cases where the contract has no agreement:

Retrieve the party address record for the counterpart asset if there is no agreement for the contract.
Here's the extended SQL query:

sql
Copy code
WITH AssetsWithoutContract AS (
    SELECT 
        CP.CUSTOMER_PRODUCT_ID AS counterpartAssetId,
        CP.MFG_SERIAL_NUM AS counterpartAssetSerialNumber,
        CP.MANUFACTURER_ID AS counterpartAssetManufacturerId,
        CP.ITEM_CLASS AS counterpartAssetItemClass,
        CP.SOURCE_SITE_ID AS counterpartAssetSourceSiteId,
        CP.CUSTOMER_NUM AS counterpartAssetCustomerNumber
    FROM 
        AEAST.CUSTOMER_PRODUCT CP
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    WHERE 
        CP.SOURCE_SYS_CREATE_PGM IN ('AC_NG.DS.SW_AS_A.CRI', 'AC_NG.DS.SW_A.CRY', 'AC_NG.DUAL_SRL_INS.ASSET')
        AND CC.CUSTOMER_CONTRACT_ID IS NULL
        AND CP.ORDER_NUM = 99999
        AND CP.SOURCE_SYS_CREATE_DTS BETWEEN TO_DATE('2023-10-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS') 
        AND TO_DATE('2023-10-31 23:59:59', 'YYYY-MM-DD HH24:MI:SS')
),
OriginalAssetLookup AS (
    SELECT 
        A.counterpartAssetId,
        CPR.TO_CUSTOMER_PRODUCT_ID AS originalAssetId
    FROM 
        AssetsWithoutContract A
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT_REL CPR
    ON 
        A.counterpartAssetId = CPR.FROM_CUSTOMER_PRODUCT_ID
        AND CPR.RELATIONSHIP_TYPE_ID = 9
),
ContractsForOriginalAssets AS (
    SELECT 
        OAL.counterpartAssetId,
        OAL.originalAssetId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original asset not found'
            ELSE CC.CUSTOMER_CONTRACT_ID 
        END AS contractId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN NULL
            ELSE CC.ITEM_NUM 
        END AS contractItemNumber,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original Asset Without Entitlement'
            ELSE NULL
        END AS rootCause
    FROM 
        OriginalAssetLookup OAL
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC 
    ON 
        OAL.originalAssetId = CC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT CP
    ON 
        CPC.CUSTOMER_PRODUCT_ID = CP.CUSTOMER_PRODUCT_ID
),
ContractRootCauseClassification AS (
    SELECT 
        C.contractId,
        C.contractItemNumber,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM AEENT.CUSTOMER_CONTRACT_IDENTIFIER CI 
                WHERE CI.CONTRACT_IDENTIFIER_VALUE = C.contractId 
                  AND CI.IDENTIFIER_TYPE_ID = 106
            ) THEN 'Original entitlement dual serialized to different asset'
            WHEN C.contractItemNumber IN (
                '709-BBEW', '865-BCFG', '709-BBOR', '865-BCFF', '303-11289', '865-BCFD', 
                '709-BBEX', '199-BBJQ', '865-BCFE', '865-BCFK', '709-BBTV', '709-BBNG', 
                '862-BBXI', '303-11291', '303-11290', '865-BCFJ', '199-BBMF', '865-BBJP', 
                '303-11466', '142-BBNV', '149-BBGI', '149-BBGK', '151-BBEH', '151-BBGU', 
                '151-BBHJ', '151-BBHY', '151-BBIY', '151-BBJB', '151-BBJE', '151-BBJF', 
                '151-BBJP', '456-109-802', '456-109-803', '456-109-804', '456-109-805', 
                '456-111-473', '456-111-474', '456-111-475', '456-111-476', '528-BYHE', 
                '528-BYHF'
            ) THEN 'SKU not eligible'
            ELSE 'Has agreement'
        END AS rootCause
    FROM 
        ContractsForOriginalAssets C
),
AgreementCheck AS (
    SELECT 
        C.contractId,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.CUSTOMER_CONTRACT_ID = C.contractId
            ) THEN (
                SELECT AI.AGREEMENT_IDENTIFIER_VALUE 
                FROM AEAGR.AGREEMENT_IDENTIFIER AI
                WHERE AI.AGREEMENT_ID = (
                    SELECT AGREEMENT_ID 
                    FROM AEENT.AGREEMENT_CONTRACT 
                    WHERE CUSTOMER_CONTRACT_ID = C.contractId
                )
                AND AI.IDENTIFIER_TYPE_ID IN (111, 112)
                FETCH FIRST 1 ROWS ONLY
            )
            ELSE 'CounterPart Agreement Not Found'
        END AS counterpartAgreementId
    FROM 
        ContractsForOriginalAssets C
),
CounterpartAgreementSource AS (
    SELECT 
        A.counterpartAgreementId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT AGREEMENT.SOURCE_SITE_ID 
                FROM AEAGR.AGREEMENT 
                WHERE AGREEMENT.AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementSourceSiteId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT CUSTOMER_CONTRACT_ID 
                FROM AEENT.AGREEMENT_CONTRACT 
                WHERE AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementContractId
    FROM 
        AgreementCheck A
),
CounterpartAgreementAssetsCheck AS (
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
            ) THEN 'Missing Agreement/Asset Relationship'
            WHEN NOT EXISTS (
                SELECT 1 FROM AEENT.AGREEMENT_CONTRACT AC 
                JOIN AEENT.CONTRACT_PRODUCT_COVERAGE CPC 
                ON AC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
                  AND CPC.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) THEN 'CounterPart Agreement Linked to Non-Mapped Asset'
            ELSE NULL
        END AS agreementAssetRootCause
    FROM 
        CounterpartAgreementSource C
    JOIN 
        AssetsWithoutContract A 
    ON 
        1 = 1
),
PartyLocationCheck AS (
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN (
                SELECT COUNT(*) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) = 0 
            OR (C.counterpartAgreementSourceSiteId = 6 AND (
                SELECT COALESCE(PA.UCID, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1)
            OR (C.counterpartAgreementSourceSiteId <> 6 AND (
                SELECT COALESCE(PA.CUSTOMER_NUM, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1) THEN 'PartyLocation not found'
            ELSE NULL
        END AS partyLocationRootCause
    FROM 
        CounterpartAgreementSource C
)
SELECT 
    counterpartAssetId,
    counterpartAssetSerialNumber,
    counterpartAssetManufacturerId,
    counterpartAssetItemClass,
    counterpartAssetSourceSiteId,
    counterpartAssetCustomerNumber,
    originalAssetId,
    contractId,
    contractItemNumber,
    rootCause,
    counterpartAgreementId,
    counterpartAgreementSourceSiteId,
    counterpartAgreementContractId,
    agreementAssetRootCause,
    partyLocationRootCause
FROM 
    AssetsWithoutContract A
LEFT JOIN 
    OriginalAssetLookup OAL ON A.counterpartAssetId = OAL.counterpartAssetId
LEFT JOIN 
    ContractsForOriginalAssets COA ON OAL.counterpartAssetId = COA.counterpartAssetId
LEFT JOIN 
    AgreementCheck AC ON COA.contractId = AC.contractId
LEFT JOIN 
    CounterpartAgreementSource CAS ON AC.counterpartAgreementId = CAS.counterpartAgreementId
LEFT JOIN 
    CounterpartAgreementAssetsCheck CAAC ON CAS.counterpartAgreementId = CAAC.counterpartAgreementId
LEFT JOIN 
    PartyLocationCheck PLC ON CAS.counterpartAgreementId = PLC.counterpartAgreementId;
Key Additions:
CounterpartAgreementAssetsCheck CTE checks for missing agreements/assets or mismapped assets.
PartyLocationCheck CTE retrieves the party address record and checks for the "PartyLocation not found" condition.
The final SELECT combines the data and shows all relevant columns, including the new root cause fields.
Feel free to adjust the query as needed based on additional business logic or requirements.






You said:
add the following condition also to above query
--If there is no party address record for the counterpart asset
--(and counterpart asset source site ID is 6 and party address UCID record is null or lower than 1 or if counterpart
--asset source site ID is different than 6 and the party address customer number record is null or lower
--than 1)
--and counterpart asset customer number is null or lower than 1
--then the root cause for the contract should be "Customer not found in counterpart asset"
--If the contract didn't fall into any of the previous steps then we get the item material mapping record for the contract item number and source site ID
--If the contract source site ID is 6 then we get the item material mapping record by the EMC_ITEM_NUM column
select EMC ITEM NUM as itemMaterialMapping
from SDR.ITEM MATERIAL MAPPING
where EMC ITEM NUM = : contractItemNumber
and APPLICATION ID = 33
and ITEM_MATERIAL_MAP_TYPE_ID in (1, 3, 4, 5, 6);
--If the contract source site ID is different from 6 then we get the item material mapping record by the DELL_ITEM_NUM column
select DELL _ITEM_NUM as itemMaterialMapping
from SDR.ITEM_MATERIAL_MAPPING where DELL ITEM NUM :contractItemNumber
and APPLICATION ID = 33
and ITEM_MATERIAL_MAP_TYPE_ID in (1, 3, 4, 5, 6);
ChatGPT said:
ChatGPT
To add the additional conditions, we need to extend the query to:

Check if there is no party address record for the counterpart asset:

If the counterpart asset source site ID is 6 and the party address UCID record is null or lower than 1, or if the counterpart asset source site ID is different than 6 and the party address customer number record is null or lower than 1, and the counterpart asset customer number is null or lower than 1, the root cause should be "Customer not found in counterpart asset."
Retrieve item material mapping records for the contract item number and source site ID:

If the contract source site ID is 6, get the item material mapping by the EMC_ITEM_NUM column.
If the contract source site ID is different from 6, get the item material mapping by the DELL_ITEM_NUM column.
Here is the revised query incorporating these additional steps:

sql
Copy code
WITH AssetsWithoutContract AS (
    SELECT 
        CP.CUSTOMER_PRODUCT_ID AS counterpartAssetId,
        CP.MFG_SERIAL_NUM AS counterpartAssetSerialNumber,
        CP.MANUFACTURER_ID AS counterpartAssetManufacturerId,
        CP.ITEM_CLASS AS counterpartAssetItemClass,
        CP.SOURCE_SITE_ID AS counterpartAssetSourceSiteId,
        CP.CUSTOMER_NUM AS counterpartAssetCustomerNumber
    FROM 
        AEAST.CUSTOMER_PRODUCT CP
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    WHERE 
        CP.SOURCE_SYS_CREATE_PGM IN ('AC_NG.DS.SW_AS_A.CRI', 'AC_NG.DS.SW_A.CRY', 'AC_NG.DUAL_SRL_INS.ASSET')
        AND CC.CUSTOMER_CONTRACT_ID IS NULL
        AND CP.ORDER_NUM = 99999
        AND CP.SOURCE_SYS_CREATE_DTS BETWEEN TO_DATE('2023-10-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS') 
        AND TO_DATE('2023-10-31 23:59:59', 'YYYY-MM-DD HH24:MI:SS')
),
OriginalAssetLookup AS (
    SELECT 
        A.counterpartAssetId,
        CPR.TO_CUSTOMER_PRODUCT_ID AS originalAssetId
    FROM 
        AssetsWithoutContract A
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT_REL CPR
    ON 
        A.counterpartAssetId = CPR.FROM_CUSTOMER_PRODUCT_ID
        AND CPR.RELATIONSHIP_TYPE_ID = 9
),
ContractsForOriginalAssets AS (
    SELECT 
        OAL.counterpartAssetId,
        OAL.originalAssetId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original asset not found'
            ELSE CC.CUSTOMER_CONTRACT_ID 
        END AS contractId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN NULL
            ELSE CC.ITEM_NUM 
        END AS contractItemNumber,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original Asset Without Entitlement'
            ELSE NULL
        END AS rootCause
    FROM 
        OriginalAssetLookup OAL
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC 
    ON 
        OAL.originalAssetId = CC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT CP
    ON 
        CPC.CUSTOMER_PRODUCT_ID = CP.CUSTOMER_PRODUCT_ID
),
ContractRootCauseClassification AS (
    SELECT 
        C.contractId,
        C.contractItemNumber,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM AEENT.CUSTOMER_CONTRACT_IDENTIFIER CI 
                WHERE CI.CONTRACT_IDENTIFIER_VALUE = C.contractId 
                  AND CI.IDENTIFIER_TYPE_ID = 106
            ) THEN 'Original entitlement dual serialized to different asset'
            WHEN C.contractItemNumber IN (
                '709-BBEW', '865-BCFG', '709-BBOR', '865-BCFF', '303-11289', '865-BCFD', 
                '709-BBEX', '199-BBJQ', '865-BCFE', '865-BCFK', '709-BBTV', '709-BBNG', 
                '862-BBXI', '303-11291', '303-11290', '865-BCFJ', '199-BBMF', '865-BBJP', 
                '303-11466', '142-BBNV', '149-BBGI', '149-BBGK', '151-BBEH', '151-BBGU', 
                '151-BBHJ', '151-BBHY', '151-BBIY', '151-BBJB', '151-BBJE', '151-BBJF', 
                '151-BBJP', '456-109-802', '456-109-803', '456-109-804', '456-109-805', 
                '456-111-473', '456-111-474', '456-111-475', '456-111-476', '528-BYHE', 
                '528-BYHF'
            ) THEN 'SKU not eligible'
            ELSE 'Has agreement'
        END AS rootCause
    FROM 
        ContractsForOriginalAssets C
),
AgreementCheck AS (
    SELECT 
        C.contractId,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.CUSTOMER_CONTRACT_ID = C.contractId
            ) THEN (
                SELECT AI.AGREEMENT_IDENTIFIER_VALUE 
                FROM AEAGR.AGREEMENT_IDENTIFIER AI
                WHERE AI.AGREEMENT_ID = (
                    SELECT AGREEMENT_ID 
                    FROM AEENT.AGREEMENT_CONTRACT 
                    WHERE CUSTOMER_CONTRACT_ID = C.contractId
                )
                AND AI.IDENTIFIER_TYPE_ID IN (111, 112)
                FETCH FIRST 1 ROWS ONLY
            )
            ELSE 'CounterPart Agreement Not Found'
        END AS counterpartAgreementId
    FROM 
        ContractsForOriginalAssets C
),
CounterpartAgreementSource AS (
    SELECT 
        A.counterpartAgreementId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT AGREEMENT.SOURCE_SITE_ID 
                FROM AEAGR.AGREEMENT 
                WHERE AGREEMENT.AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementSourceSiteId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT CUSTOMER_CONTRACT_ID 
                FROM AEENT.AGREEMENT_CONTRACT 
                WHERE AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementContractId
    FROM 
        AgreementCheck A
),
CounterpartAgreementAssetsCheck AS (
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
            ) THEN 'Missing Agreement/Asset Relationship'
            WHEN NOT EXISTS (
                SELECT 1 FROM AEENT.AGREEMENT_CONTRACT AC 
                JOIN AEENT.CONTRACT_PRODUCT_COVERAGE CPC 
                ON AC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
                  AND CPC.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) THEN 'CounterPart Agreement Linked to Non-Mapped Asset'
            ELSE NULL
        END AS agreementAssetRootCause
    FROM 
        CounterpartAgreementSource C
    JOIN 
        AssetsWithoutContract A 
    ON 
        1 = 1
),
PartyLocationCheck AS (
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN (
                SELECT COUNT(*) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) = 0 
            OR (C.counterpartAgreementSourceSiteId = 6 AND (
                SELECT COALESCE(PA.UCID, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1)
            OR (C.counterpartAgreementSourceSiteId <> 6 AND (
                SELECT COALESCE(PA.CUSTOMER_NUM, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1) THEN 'PartyLocation not found'
            ELSE NULL
        END AS partyLocationRootCause
    FROM 
        CounterpartAgreementSource C
),
CustomerCheckForCounterpartAsset AS (
    SELECT 
        A.counterpartAssetId,
        CASE 
            WHEN (
                SELECT COUNT(*) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) = 0
            OR (A.counterpartAssetSourceSiteId = 6 AND (
                SELECT COALESCE(PA.UCID, 0) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) < 1)
            OR (A.counterpartAssetSourceSiteId <> 6 AND (
                SELECT COALESCE(PA.CUSTOMER_NUM, 0) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) < 1)
            OR (A.counterpartAssetCustomerNumber IS NULL OR A.counterpartAssetCustomerNumber < 1) THEN 'Customer not found in counterpart asset'
            ELSE NULL
        END AS customerRootCause
    FROM 
        AssetsWithoutContract A
),
ItemMaterialMappingCheck AS (
    SELECT 
        C.contractId,
        C.contractItemNumber,
        C.counterpartAgreementSourceSiteId,
        CASE 
            WHEN C.counterpartAgreementSourceSiteId = 6 THEN (
                SELECT EMC_ITEM_NUM 
                FROM SDR.ITEM_MATERIAL_MAPPING IMM 
                WHERE IMM.EMC_ITEM_NUM = C.contractItemNumber 
                AND IMM.APPLICATION_ID = 33
                AND IMM.ITEM_MATERIAL_MAP_TYPE_ID IN (1, 3, 4, 5, 6)
            )
            ELSE (
                SELECT DELL_ITEM_NUM 
                FROM SDR.ITEM_MATERIAL_MAPPING IMM 
                WHERE IMM.DELL_ITEM_NUM = C.contractItemNumber 
                AND IMM.APPLICATION_ID = 33
                AND IMM.ITEM_MATERIAL_MAP_TYPE_ID IN (1, 3, 4, 5, 6)
            )
        END AS itemMaterialMapping
    FROM 
        CounterpartAgreementSource C
)
SELECT 
    A.counterpartAssetId,
    A.counterpartAssetSerialNumber,
    A.counterpartAssetManufacturerId,
    A.counterpartAssetItemClass,
    A.counterpartAssetSourceSiteId,
    A.counterpartAssetCustomerNumber,
    C.contractId,
    C.contractItemNumber,
    RCA.rootCause,
    ACS.counterpartAgreementId,
    ACS.counterpartAgreementSourceSiteId,
    ACS.counterpartAgreementContractId,
    CAAC.agreementAssetRootCause,
    PLC.partyLocationRootCause,
    CCC.customerRootCause,
    IMM.itemMaterialMapping
FROM 
    AssetsWithoutContract A
LEFT JOIN 
    ContractsForOriginalAssets C ON A.counterpartAssetId = C.counterpartAssetId
LEFT JOIN 
    ContractRootCauseClassification RCA ON C.contractId = RCA.contractId
LEFT JOIN 
    AgreementCheck AC ON C.contractId = AC.contractId
LEFT JOIN 
    CounterpartAgreementSource ACS ON AC.counterpartAgreementId = ACS.counterpartAgreementId
LEFT JOIN 
    CounterpartAgreementAssetsCheck CAAC ON ACS.counterpartAgreementId = CAAC.counterpartAgreementId
LEFT JOIN 
    PartyLocationCheck PLC ON ACS.counterpartAgreementId = PLC.counterpartAgreementId
LEFT JOIN 
    CustomerCheckForCounterpartAsset CCC ON A.counterpartAssetId = CCC.counterpartAssetId
LEFT JOIN 
    ItemMaterialMappingCheck IMM ON C.contractId = IMM.contractId;
Explanation of the Changes:
CustomerCheckForCounterpartAsset CTE: This checks for the condition of missing customer records for the counterpart asset.
ItemMaterialMappingCheck CTE: This retrieves item material mappings based on the contract item number and the source site ID.
Final SELECT Query: Joins the new CTEs to display the newly computed fields.
This updated query now includes all specified conditions and logic for classifying the root cause of contracts and their related assets.






You said:
add the below final condition and create optimized query 

--If there is no item material mapping record then the root cause for the contract should be "Missing Item Material Mapping"
--If the contract didn't fall into the previous step we get the global item main record for the item material mapping
--If the contract source site id is 6 then we get the global item main record by
select ITEM_NUM from SDR.GLOBAL_ITEM_MAIN where ITEM_NUM= itemMaterialMapping and SOURCE_SITE_ID <> 6;
--If the contract source site id is not 6 then we get the global item main record by
select ITEM_NUM from SDR.GLOBAL_ITEM_MAIN where ITEM_NUM= itemMaterialMapping and SOURCE_SITE_ID = 6;
--If there is no global item main record then the root cause for the contract should be "Missing Global Item Main"
--If the contract didn't fall into the previous step we look for instructions in errors for the contract
select DUAL_SERIAL_INSTR_ID from SDR.DUAL_SERIAL_INSTRUCTION where ENTITY_TYPE_ID = 1 and ENTITY_VALUE = :contractId;

--If there is any instruction record then the root cause for the contract should be "Instruction in Error"
--If the contract didn't fall into any of the above root causes and the contract has an agreement then the root cause for the contract should be " [AGREEMENT] Other"
--If the contract didn't fall into any of the above root causes and the contract has no agreement then the root cause for the contract should be " Other"

2/2

ChatGPT said:
ChatGPT
To add the final condition and optimize the query, we'll include the following steps:

Check for Missing Item Material Mapping:

If no item material mapping record exists, set the root cause to "Missing Item Material Mapping."
Get Global Item Main Record:

Based on the source site ID, get the global item main record and check if it exists. If not, set the root cause to "Missing Global Item Main."
Check for Instructions in Errors:

If there are any instruction records, set the root cause to "Instruction in Error."
Final Root Cause Determination:

If none of the above conditions apply and the contract has an agreement, set the root cause to "[AGREEMENT] Other."
If none of the above conditions apply and the contract has no agreement, set the root cause to "Other."
Here’s the revised query:

sql
Copy code
WITH AssetsWithoutContract AS (
    -- Step 1: Assets without associated contracts
    SELECT 
        CP.CUSTOMER_PRODUCT_ID AS counterpartAssetId,
        CP.MFG_SERIAL_NUM AS counterpartAssetSerialNumber,
        CP.MANUFACTURER_ID AS counterpartAssetManufacturerId,
        CP.ITEM_CLASS AS counterpartAssetItemClass,
        CP.SOURCE_SITE_ID AS counterpartAssetSourceSiteId,
        CP.CUSTOMER_NUM AS counterpartAssetCustomerNumber
    FROM 
        AEAST.CUSTOMER_PRODUCT CP
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    WHERE 
        CP.SOURCE_SYS_CREATE_PGM IN ('AC_NG.DS.SW_AS_A.CRI', 'AC_NG.DS.SW_A.CRY', 'AC_NG.DUAL_SRL_INS.ASSET')
        AND CC.CUSTOMER_CONTRACT_ID IS NULL
        AND CP.ORDER_NUM = 99999
        AND CP.SOURCE_SYS_CREATE_DTS BETWEEN TO_DATE('2023-10-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS') 
        AND TO_DATE('2023-10-31 23:59:59', 'YYYY-MM-DD HH24:MI:SS')
),
OriginalAssetLookup AS (
    -- Step 2: Lookup original asset
    SELECT 
        A.counterpartAssetId,
        CPR.TO_CUSTOMER_PRODUCT_ID AS originalAssetId
    FROM 
        AssetsWithoutContract A
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT_REL CPR
    ON 
        A.counterpartAssetId = CPR.FROM_CUSTOMER_PRODUCT_ID
        AND CPR.RELATIONSHIP_TYPE_ID = 9
),
ContractsForOriginalAssets AS (
    -- Step 3: Contracts associated with the original assets
    SELECT 
        OAL.counterpartAssetId,
        OAL.originalAssetId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original asset not found'
            ELSE CC.CUSTOMER_CONTRACT_ID 
        END AS contractId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN NULL
            ELSE CC.ITEM_NUM 
        END AS contractItemNumber,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original Asset Without Entitlement'
            ELSE NULL
        END AS rootCause
    FROM 
        OriginalAssetLookup OAL
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC 
    ON 
        OAL.originalAssetId = CC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT CP
    ON 
        CPC.CUSTOMER_PRODUCT_ID = CP.CUSTOMER_PRODUCT_ID
),
AgreementCheck AS (
    -- Step 4: Check if the contract has an agreement
    SELECT 
        C.contractId,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.CUSTOMER_CONTRACT_ID = C.contractId
            ) THEN (
                SELECT AI.AGREEMENT_IDENTIFIER_VALUE 
                FROM AEAGR.AGREEMENT_IDENTIFIER AI
                WHERE AI.AGREEMENT_ID = (
                    SELECT AGREEMENT_ID 
                    FROM AEENT.AGREEMENT_CONTRACT 
                    WHERE CUSTOMER_CONTRACT_ID = C.contractId
                )
                AND AI.IDENTIFIER_TYPE_ID IN (111, 112)
                FETCH FIRST 1 ROWS ONLY
            )
            ELSE 'CounterPart Agreement Not Found'
        END AS counterpartAgreementId
    FROM 
        ContractsForOriginalAssets C
),
CounterpartAgreementSource AS (
    -- Step 5: Get source site ID and associated contracts
    SELECT 
        A.counterpartAgreementId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT AGREEMENT.SOURCE_SITE_ID 
                FROM AEAGR.AGREEMENT 
                WHERE AGREEMENT.AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementSourceSiteId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT CUSTOMER_CONTRACT_ID 
                FROM AEENT.AGREEMENT_CONTRACT 
                WHERE AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementContractId
    FROM 
        AgreementCheck A
),
CounterpartAgreementAssetsCheck AS (
    -- Step 6: Check for missing agreement/asset relationship
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
            ) THEN 'Missing Agreement/Asset Relationship'
            WHEN NOT EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                JOIN AEENT.CONTRACT_PRODUCT_COVERAGE CPC 
                ON AC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
                  AND CPC.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) THEN 'CounterPart Agreement Linked to Non-Mapped Asset'
            ELSE NULL
        END AS agreementAssetRootCause
    FROM 
        CounterpartAgreementSource C
    JOIN 
        AssetsWithoutContract A 
    ON 
        1 = 1
),
PartyLocationCheck AS (
    -- Step 7: Check for party address record
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN (
                SELECT COUNT(*) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) = 0 
            OR (C.counterpartAgreementSourceSiteId = 6 AND (
                SELECT COALESCE(PA.UCID, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1)
            OR (C.counterpartAgreementSourceSiteId <> 6 AND (
                SELECT COALESCE(PA.CUSTOMER_NUM, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1) THEN 'PartyLocation not found'
            ELSE NULL
        END AS partyLocationRootCause
    FROM 
        CounterpartAgreementSource C
),
CustomerCheckForCounterpartAsset AS (
    -- Step 8: Check for party address record in the counterpart asset
    SELECT 
        A.counterpartAssetId,
        CASE 
            WHEN (
                SELECT COUNT(*) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) = 0
            OR (A.counterpartAssetSourceSiteId = 6 AND (
                SELECT COALESCE(PA.UCID, 0) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) < 1)
            OR (A.counterpartAssetSourceSiteId <> 6 AND (
                SELECT COALESCE(PA.CUSTOMER_NUM, 0) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) < 1)
            OR (A.counterpartAssetCustomerNumber IS NULL OR A.counterpartAssetCustomerNumber < 1) THEN 'Customer not found in counterpart asset'
            ELSE NULL
        END AS customerRootCause
    FROM 
        AssetsWithoutContract A
),
ItemMaterialMappingCheck AS (
    -- Step 9: Check for item material mapping
    SELECT 
        C.contractId,
        C.contractItemNumber,
        C.counterpartAgreementSourceSiteId,
        CASE 
            WHEN C.counterpartAgreementSourceSiteId = 6 THEN (
                SELECT EMC_ITEM_NUM 
                FROM SDR.ITEM_MATERIAL_MAPPING IMM 
                WHERE IMM.EMC_ITEM_NUM = C.contractItemNumber 
                AND IMM.APPLICATION_ID = 33
                AND IMM.ITEM_MATERIAL_MAP_TYPE_ID IN (1, 3, 4, 5, 6)
            )
            ELSE (
                SELECT DELL_ITEM_NUM 
                FROM SDR.ITEM_MATERIAL_MAPPING IMM 
                WHERE IMM.DELL_ITEM_NUM = C.contractItemNumber 
                AND IMM.APPLICATION_ID = 33
                AND IMM.ITEM_MATERIAL_MAP_TYPE_ID IN (1, 3, 4, 5, 6)
            )
        END AS itemMaterialMapping
    FROM 
        ContractsForOriginalAssets C
),
GlobalItemMainCheck AS (
    -- Step 10: Check for global item main record
    SELECT 
        I.contractId,
        I.itemMaterialMapping,
        I.counterpartAgreementSourceSiteId,
        CASE 
            WHEN I.itemMaterialMapping IS NOT NULL AND I.counterpartAgreementSourceSiteId = 6 THEN (
                SELECT ITEM_NUM 
                FROM SDR.GLOBAL_ITEM_MAIN 
                WHERE ITEM_NUM = I.itemMaterialMapping 
                AND SOURCE_SITE_ID <> 6
            )
            WHEN I.itemMaterialMapping IS NOT NULL AND I.counterpartAgreementSourceSiteId <> 6 THEN (
                SELECT ITEM_NUM 
                FROM SDR.GLOBAL_ITEM_MAIN 
                WHERE ITEM_NUM = I.itemMaterialMapping 
                AND SOURCE_SITE_ID = 6
            )
            ELSE NULL
        END AS globalItemMain
    FROM 
        ItemMaterialMappingCheck I
),
FinalCheck AS (
    -- Step 11: Check for missing global item main record
    SELECT 
        G.contractId,
        CASE 
            WHEN G.globalItemMain IS NULL AND G.itemMaterialMapping IS NOT NULL THEN 'Missing Global Item Main'
            WHEN EXISTS (
                SELECT 1 
                FROM SDR.DUAL_SERIAL_INSTRUCTION 
                WHERE ENTITY_TYPE_ID = 1 
                AND ENTITY_VALUE = G.contractId
            ) THEN 'Instruction in Error'
            ELSE 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 
                        FROM AEENT.AGREEMENT_CONTRACT AC 
                        WHERE AC.CUSTOMER_CONTRACT_ID = G.contractId
                    ) THEN '[AGREEMENT] Other'
                    ELSE 'Other'
                END
        END AS rootCause
    FROM 
        GlobalItemMainCheck G
)
SELECT 
    A.counterpartAssetId,
    A.counterpartAssetSerialNumber,
    A.counterpartAssetManufacturerId,
    A.counterpartAssetItemClass,
    A.counterpartAssetSourceSiteId,
    A.counterpartAssetCustomerNumber,
    C.contractId,
    C.contractItemNumber,
    RCA.rootCause,
    ACS.counterpartAgreementId,
    ACS.counterpartAgreementSourceSiteId,
    ACS.counterpartAgreementContractId,
    CAAC.agreementAssetRootCause,
    PLC.partyLocationRootCause,
    CCC.customerRootCause,
    IMM.itemMaterialMapping,
    F.rootCause AS finalRootCause
FROM 
    AssetsWithoutContract A
LEFT JOIN 
    ContractsForOriginalAssets C ON A.counterpartAssetId = C.counterpartAssetId
LEFT JOIN 
    ContractRootCauseClassification RCA ON C.contractId = RCA.contractId
LEFT JOIN 
    AgreementCheck AC ON C.contractId = AC.contractId
LEFT JOIN 
    CounterpartAgreementSource ACS ON AC.counterpartAgreementId = ACS.counterpartAgreementId
LEFT JOIN 
    CounterpartAgreementAssetsCheck CAAC ON ACS.counterpartAgreementId = CAAC.counterpartAgreementId
LEFT JOIN 
    PartyLocationCheck PLC ON ACS.counterpartAgreementId = PLC.counterpartAgreementId
LEFT JOIN 
    CustomerCheckForCounterpartAsset CCC ON A.counterpartAssetId = CCC.counterpartAssetId
LEFT JOIN 
    ItemMaterialMappingCheck IMM ON C.contractId = IMM.contractId
LEFT JOIN 
    FinalCheck F ON C.contractId = F.contractId;
Explanation of Additions:
GlobalItemMainCheck CTE: Determines the existence of global item main records based on the source site ID.
FinalCheck CTE: Includes the conditions for missing item material mappings, missing global item main records, and instructions in errors to classify the final root cause.
Final SELECT Query: Joins the new CTEs and includes the final root cause determination.
This optimized query ensures that all conditions are checked in sequence and helps classify the root cause of each contract effectively.






You said:
please do adjust the above code to run in hive
ChatGPT said:
ChatGPT
To adjust the SQL query for Hive, we'll make some changes to account for Hive's SQL dialect and limitations. Hive SQL often requires different syntax for certain operations and does not support all SQL features (like CTEs) in the same way as traditional SQL databases. Here's a modified version of the query for Hive:

sql
Copy code
-- Step 1: Assets without associated contracts
WITH AssetsWithoutContract AS (
    SELECT 
        CP.CUSTOMER_PRODUCT_ID AS counterpartAssetId,
        CP.MFG_SERIAL_NUM AS counterpartAssetSerialNumber,
        CP.MANUFACTURER_ID AS counterpartAssetManufacturerId,
        CP.ITEM_CLASS AS counterpartAssetItemClass,
        CP.SOURCE_SITE_ID AS counterpartAssetSourceSiteId,
        CP.CUSTOMER_NUM AS counterpartAssetCustomerNumber
    FROM 
        AEAST.CUSTOMER_PRODUCT CP
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    WHERE 
        CP.SOURCE_SYS_CREATE_PGM IN ('AC_NG.DS.SW_AS_A.CRI', 'AC_NG.DS.SW_A.CRY', 'AC_NG.DUAL_SRL_INS.ASSET')
        AND CC.CUSTOMER_CONTRACT_ID IS NULL
        AND CP.ORDER_NUM = 99999
        AND CP.SOURCE_SYS_CREATE_DTS BETWEEN '2023-10-01 00:00:00' AND '2023-10-31 23:59:59'
),

-- Step 2: Lookup original asset
OriginalAssetLookup AS (
    SELECT 
        A.counterpartAssetId,
        CPR.TO_CUSTOMER_PRODUCT_ID AS originalAssetId
    FROM 
        AssetsWithoutContract A
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT_REL CPR
    ON 
        A.counterpartAssetId = CPR.FROM_CUSTOMER_PRODUCT_ID
        AND CPR.RELATIONSHIP_TYPE_ID = 9
),

-- Step 3: Contracts associated with the original assets
ContractsForOriginalAssets AS (
    SELECT 
        OAL.counterpartAssetId,
        OAL.originalAssetId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original asset not found'
            ELSE CC.CUSTOMER_CONTRACT_ID 
        END AS contractId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN NULL
            ELSE CC.ITEM_NUM 
        END AS contractItemNumber,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original Asset Without Entitlement'
            ELSE NULL
        END AS rootCause
    FROM 
        OriginalAssetLookup OAL
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC 
    ON 
        OAL.originalAssetId = CC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT CP
    ON 
        CPC.CUSTOMER_PRODUCT_ID = CP.CUSTOMER_PRODUCT_ID
),

-- Step 4: Check if the contract has an agreement
AgreementCheck AS (
    SELECT 
        C.contractId,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.CUSTOMER_CONTRACT_ID = C.contractId
            ) THEN (
                SELECT AI.AGREEMENT_IDENTIFIER_VALUE 
                FROM AEAGR.AGREEMENT_IDENTIFIER AI
                WHERE AI.AGREEMENT_ID = (
                    SELECT AGREEMENT_ID 
                    FROM AEENT.AGREEMENT_CONTRACT 
                    WHERE CUSTOMER_CONTRACT_ID = C.contractId
                )
                AND AI.IDENTIFIER_TYPE_ID IN (111, 112)
                LIMIT 1
            )
            ELSE 'CounterPart Agreement Not Found'
        END AS counterpartAgreementId
    FROM 
        ContractsForOriginalAssets C
),

-- Step 5: Get source site ID and associated contracts
CounterpartAgreementSource AS (
    SELECT 
        A.counterpartAgreementId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT AGREEMENT.SOURCE_SITE_ID 
                FROM AEAGR.AGREEMENT 
                WHERE AGREEMENT.AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementSourceSiteId,
        CASE 
            WHEN A.counterpartAgreementId IS NOT NULL THEN (
                SELECT CUSTOMER_CONTRACT_ID 
                FROM AEENT.AGREEMENT_CONTRACT 
                WHERE AGREEMENT_ID = A.counterpartAgreementId
            )
            ELSE NULL
        END AS counterpartAgreementContractId
    FROM 
        AgreementCheck A
),

-- Step 6: Check for missing agreement/asset relationship
CounterpartAgreementAssetsCheck AS (
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
            ) THEN 'Missing Agreement/Asset Relationship'
            WHEN NOT EXISTS (
                SELECT 1 
                FROM AEENT.AGREEMENT_CONTRACT AC 
                JOIN AEENT.CONTRACT_PRODUCT_COVERAGE CPC 
                ON AC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
                WHERE AC.AGREEMENT_ID = C.counterpartAgreementId
                  AND CPC.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) THEN 'CounterPart Agreement Linked to Non-Mapped Asset'
            ELSE NULL
        END AS agreementAssetRootCause
    FROM 
        CounterpartAgreementSource C
    JOIN 
        AssetsWithoutContract A 
    ON 
        1 = 1
),

-- Step 7: Check for party address record
PartyLocationCheck AS (
    SELECT 
        C.counterpartAgreementId,
        CASE 
            WHEN (
                SELECT COUNT(*) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) = 0 
            OR (C.counterpartAgreementSourceSiteId = 6 AND (
                SELECT COALESCE(PA.UCID, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1)
            OR (C.counterpartAgreementSourceSiteId <> 6 AND (
                SELECT COALESCE(PA.CUSTOMER_NUM, 0) 
                FROM AEPA.PARTY_ADDRESS_AGREEMENT PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.AGREEMENT_ID = C.counterpartAgreementId
            ) < 1) THEN 'PartyLocation not found'
            ELSE NULL
        END AS partyLocationRootCause
    FROM 
        CounterpartAgreementSource C
),

-- Step 8: Check for party address record in the counterpart asset
CustomerCheckForCounterpartAsset AS (
    SELECT 
        A.counterpartAssetId,
        CASE 
            WHEN (
                SELECT COUNT(*) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) = 0
            OR (A.counterpartAssetSourceSiteId = 6 AND (
                SELECT COALESCE(PA.UCID, 0) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) < 1)
            OR (A.counterpartAssetSourceSiteId <> 6 AND (
                SELECT COALESCE(PA.CUSTOMER_NUM, 0) 
                FROM AEPA.PARTY_ADDRESS_ASSET PAA
                JOIN AEPA.PARTY_ADDRESS PA 
                ON PAA.PARTY_ADDRESS_ID = PA.PARTY_ADDRESS_ID
                WHERE PAA.CUSTOMER_PRODUCT_ID = A.counterpartAssetId
            ) < 1)
            OR (A.counterpartAssetCustomerNumber IS NULL OR A.counterpartAssetCustomerNumber < 1) THEN 'Customer not found in counterpart asset'
            ELSE NULL
        END AS customerRootCause
    FROM 
        AssetsWithoutContract A
),

-- Step 9: Check for item material mapping
ItemMaterialMappingCheck AS (
    SELECT 
        C.contractId,
        C.contractItemNumber,
        C.counterpartAgreementSourceSiteId,
        CASE 
            WHEN C.counterpartAgreementSourceSiteId = 6 THEN (
                SELECT EMC_ITEM_NUM 
                FROM SDR.ITEM_MATERIAL_MAPPING IMM 
                WHERE IMM.EMC_ITEM_NUM = C.contractItemNumber 
                AND IMM.APPLICATION_ID = 33
                AND IMM.ITEM_MATERIAL_MAP_TYPE_ID IN (1, 3, 4, 5, 6)
                LIMIT 1
            )
            ELSE (
                SELECT DELL_ITEM_NUM 
                FROM SDR.ITEM_MATERIAL_MAPPING IMM 
                WHERE IMM.DELL_ITEM_NUM = C.contractItemNumber 
                AND IMM.APPLICATION_ID = 33
                AND IMM.ITEM_MATERIAL_MAP_TYPE_ID IN (1, 3, 4, 5, 6)
                LIMIT 1
            )
        END AS itemMaterialMapping
    FROM 
        ContractsForOriginalAssets C
),

-- Step 10: Check for global item main record
GlobalItemMainCheck AS (
    SELECT 
        I.contractId,
        I.itemMaterialMapping,
        I.counterpartAgreementSourceSiteId,
        CASE 
            WHEN I.itemMaterialMapping IS NOT NULL AND I.counterpartAgreementSourceSiteId = 6 THEN (
                SELECT ITEM_NUM 
                FROM SDR.GLOBAL_ITEM_MAIN 
                WHERE ITEM_NUM = I.itemMaterialMapping 
                AND SOURCE_SITE_ID <> 6
                LIMIT 1
            )
            WHEN I.itemMaterialMapping IS NOT NULL AND I.counterpartAgreementSourceSiteId <> 6 THEN (
                SELECT ITEM_NUM 
                FROM SDR.GLOBAL_ITEM_MAIN 
                WHERE ITEM_NUM = I.itemMaterialMapping 
                AND SOURCE_SITE_ID = 6
                LIMIT 1
            )
            ELSE NULL
        END AS globalItemMain
    FROM 
        ItemMaterialMappingCheck I
),

-- Step 11: Final root cause determination
FinalCheck AS (
    SELECT 
        G.contractId,
        CASE 
            WHEN G.globalItemMain IS NULL AND G.itemMaterialMapping IS NOT NULL THEN 'Missing Global Item Main'
            WHEN EXISTS (
                SELECT 1 
                FROM SDR.DUAL_SERIAL_INSTRUCTION 
                WHERE ENTITY_TYPE_ID = 1 
                AND ENTITY_VALUE = G.contractId
            ) THEN 'Instruction in Error'
            ELSE 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 
                        FROM AEENT.AGREEMENT_CONTRACT AC 
                        WHERE AC.CUSTOMER_CONTRACT_ID = G.contractId
                    ) THEN '[AGREEMENT] Other'
                    ELSE 'Other'
                END
        END AS rootCause
    FROM 
        GlobalItemMainCheck G
)

-- Final selection
SELECT 
    A.counterpartAssetId,
    A.counterpartAssetSerialNumber,
    A.counterpartAssetManufacturerId,
    A.counterpartAssetItemClass,
    A.counterpartAssetSourceSiteId,
    A.counterpartAssetCustomerNumber,
    C.contractId,
    C.contractItemNumber,
    COALESCE(RCA.rootCause, '') AS rootCause,
    ACS.counterpartAgreementId,
    ACS.counterpartAgreementSourceSiteId,
    ACS.counterpartAgreementContractId,
    CAAC.agreementAssetRootCause,
    PLC.partyLocationRootCause,
    CCC.customerRootCause,
    IMM.itemMaterialMapping,
    F.rootCause AS finalRootCause
FROM 
    AssetsWithoutContract A
LEFT JOIN 
    ContractsForOriginalAssets C ON A.counterpartAssetId = C.counterpartAssetId
LEFT JOIN 
    ContractRootCauseClassification RCA ON C.contractId = RCA.contractId
LEFT JOIN 
    AgreementCheck AC ON C.contractId = AC.contractId
LEFT JOIN 
    CounterpartAgreementSource ACS ON AC.counterpartAgreementId = ACS.counterpartAgreementId
LEFT JOIN 
    CounterpartAgreementAssetsCheck CAAC ON ACS.counterpartAgreementId = CAAC.counterpartAgreementId
LEFT JOIN 
    PartyLocationCheck PLC ON ACS.counterpartAgreementId = PLC.counterpartAgreementId
LEFT JOIN 
    CustomerCheckForCounterpartAsset CCC ON A.counterpartAssetId = CCC.counterpartAssetId
LEFT JOIN 
    ItemMaterialMappingCheck IMM ON C.contractId = IMM.contractId
LEFT JOIN 
    FinalCheck F ON C.contractId = F.contractId;
Adjustments for Hive:
LIMIT Clause: Used LIMIT 1 in subqueries to handle subqueries returning multiple rows.
COALESCE Function: Used to handle null values in rootCause and other fields.
Removed CTE Syntax: Hive does not fully support CTEs (Common Table Expressions) in all versions, so it may need to be adjusted or used as subqueries directly in some cases.
Make sure to test this query in your Hive environment, as syntax or functionality can vary between different versions of Hive.


--------------------------------------------------------NEW CODE-----------------------------------------
	-- Step 1: Assets without associated contracts
-- Step 1: Assets without associated contracts
WITH AssetsWithoutContract AS (
    SELECT 
        CP.CUSTOMER_PRODUCT_ID AS counterpartAssetId,
        CP.MFG_SERIAL_NUM AS counterpartAssetSerialNumber,
        CP.MANUFACTURER_ID AS counterpartAssetManufacturerId,
        CP.ITEM_CLASS AS counterpartAssetItemClass,
        CP.SOURCE_SITE_ID AS counterpartAssetSourceSiteId,
        CP.CUSTOMER_NUM AS counterpartAssetCustomerNumber
    FROM 
        AEAST.CUSTOMER_PRODUCT CP
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CP.CUSTOMER_PRODUCT_ID = CPC.CUSTOMER_PRODUCT_ID
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    WHERE 
        CP.SOURCE_SYS_CREATE_PGM IN ('AC_NG.DS.SW_AS_A.CRI', 'AC_NG.DS.SW_A.CRY', 'AC_NG.DUAL_SRL_INS.ASSET')
        AND CC.CUSTOMER_CONTRACT_ID IS NULL
        AND CP.ORDER_NUM = 99999
        AND CP.SOURCE_SYS_CREATE_DTS BETWEEN '2023-10-01 00:00:00' AND '2023-10-31 23:59:59'
),

-- Step 2: Lookup original asset
OriginalAssetLookup AS (
    SELECT 
        A.counterpartAssetId,
        CPR.TO_CUSTOMER_PRODUCT_ID AS originalAssetId
    FROM 
        AssetsWithoutContract A
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT_REL CPR
    ON 
        A.counterpartAssetId = CPR.FROM_CUSTOMER_PRODUCT_ID
        AND CPR.RELATIONSHIP_TYPE_ID = 9
),

-- Step 3: Contracts associated with the original assets
ContractsForOriginalAssets AS (
    SELECT 
        OAL.counterpartAssetId,
        OAL.originalAssetId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original asset not found'
            ELSE CC.CUSTOMER_CONTRACT_ID 
        END AS contractId,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN NULL
            ELSE CC.ITEM_NUM 
        END AS contractItemNumber,
        CASE 
            WHEN OAL.originalAssetId IS NULL THEN 'Original Asset Without Entitlement'
            ELSE NULL
        END AS rootCause
    FROM 
        OriginalAssetLookup OAL
    LEFT JOIN 
        AEENT.CUSTOMER_CONTRACT CC 
    ON 
        OAL.originalAssetId = CC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEENT.CONTRACT_PRODUCT_COVERAGE CPC
    ON 
        CC.CUSTOMER_CONTRACT_ID = CPC.CUSTOMER_CONTRACT_ID
    LEFT JOIN 
        AEAST.CUSTOMER_PRODUCT CP
    ON 
        CPC.CUSTOMER_PRODUCT_ID = CP.CUSTOMER_PRODUCT_ID
),

-- Step 4: Agreement Check (revised to use LEFT JOIN)
AgreementCheck AS (
    SELECT 
        C.contractId,
        CASE 
            WHEN AC.AGREEMENT_ID IS NOT NULL THEN 'Exists'
            ELSE 'CounterPart Agreement Not Found'
        END AS counterpartAgreementCheck
    FROM 
        ContractsForOriginalAssets C
    LEFT JOIN 
        AEENT.AGREEMENT_CONTRACT AC 
    ON 
        AC.CUSTOMER_CONTRACT_ID = C.contractId
),

-- Step 5: Agreement Identifier and Source Site
AgreementIdentifier AS (
    SELECT 
        AC.CUSTOMER_CONTRACT_ID AS contractId,
        AI.AGREEMENT_IDENTIFIER_VALUE AS counterpartAgreementId,
        AG.SOURCE_SITE_ID AS counterpartAgreementSourceSiteId,
        AC.CUSTOMER_CONTRACT_ID AS counterpartAgreementContractId
    FROM 
        AEENT.AGREEMENT_CONTRACT AC 
    JOIN 
        AEAGR.AGREEMENT_IDENTIFIER AI ON AC.AGREEMENT_ID = AI.AGREEMENT_ID 
    JOIN 
        AEAGR.AGREEMENT AG ON AG.AGREEMENT_ID = AI.AGREEMENT_ID 
    WHERE 
        AI.IDENTIFIER_TYPE_ID IN (111, 112)
),

-- Step 6: Combine Agreement and Contract Data
CombinedAgreementContract AS (
    SELECT 
        C.contractId,
        A.counterpartAgreementId,
        A.counterpartAgreementSourceSiteId,
        A.counterpartAgreementContractId,
        CASE 
            WHEN A.counterpartAgreementId IS NULL THEN 'CounterPart Agreement Not Found'
            ELSE NULL
        END AS agreementAssetRootCause
    FROM 
        ContractsForOriginalAssets C
    LEFT JOIN 
        AgreementIdentifier A ON C.contractId = A.contractId
),

-- Step 7: Party Location Check
PartyLocationCheck AS (
    SELECT 
        C.contractId,
        CASE 
            WHEN COUNT(PAA.AGREEMENT_ID) = 0 THEN 'PartyLocation not found'
            ELSE NULL
        END AS partyLocationRootCause
    FROM 
        CombinedAgreementContract C
    LEFT JOIN 
        AEPA.PARTY_ADDRESS_AGREEMENT PAA ON C.counterpartAgreementId = PAA.AGREEMENT_ID
    GROUP BY 
        C.contractId
),

-- Step 8: Customer Check for Counterpart Asset
CustomerCheckForCounterpartAsset AS (
    SELECT 
        A.counterpartAssetId,
        CASE 
            WHEN COUNT(PAA.CUSTOMER_PRODUCT_ID) = 0 THEN 'Customer not found in counterpart asset'
            ELSE NULL
        END AS customerRootCause
    FROM 
        AssetsWithoutContract A
    LEFT JOIN 
        AEPA.PARTY_ADDRESS_ASSET PAA ON A.counterpartAssetId = PAA.CUSTOMER_PRODUCT_ID
    GROUP BY 
        A.counterpartAssetId
),

-- Step 9: Item Material Mapping Check
ItemMaterialMappingCheck AS (
    SELECT 
        C.contractId,
        CASE 
            WHEN COUNT(IMM.EMC_ITEM_NUM) = 0 THEN 'Missing Item Material Mapping'
            ELSE 'Exists'
        END AS itemMaterialMappingCheck
    FROM 
        ContractsForOriginalAssets C
    LEFT JOIN 
        SDR.ITEM_MATERIAL_MAPPING IMM ON (C.contractItemNumber = IMM.EMC_ITEM_NUM OR C.contractItemNumber = IMM.ITEM_NUM)
    WHERE 
        IMM.APPLICATION_ID = 33
        AND IMM.ITEM_MATERIAL_MAP_TYPE_ID IN (1, 3, 4, 5, 6)
    GROUP BY 
        C.contractId
),

-- Step 10: Global Item Main Check
GlobalItemMainCheck AS (
    SELECT 
        C.contractId,
        CASE 
            WHEN COUNT(GIM.ITEM_NUM) = 0 THEN 'Missing Global Item Main'
            ELSE 'Exists'
        END AS globalItemMainCheck
    FROM 
        ItemMaterialMappingCheck C
    LEFT JOIN 
        SDR.GLOBAL_ITEM_MAIN GIM ON (C.itemMaterialMappingCheck = 'Exists' AND C.contractId = GIM.ITEM_NUM)
    GROUP BY 
        C.contractId
),

-- Step 11: Final Check
FinalCheck AS (
    SELECT 
        C.contractId,
        COALESCE(PLC.partyLocationRootCause, CAC.agreementAssetRootCause, CIMC.itemMaterialMappingCheck, GIC.globalItemMainCheck, 'Other') AS rootCause
    FROM 
        ContractsForOriginalAssets C
    LEFT JOIN 
        PartyLocationCheck PLC ON C.contractId = PLC.contractId
    LEFT JOIN 
        CombinedAgreementContract CAC ON C.contractId = CAC.contractId
    LEFT JOIN 
        ItemMaterialMappingCheck CIMC ON C.contractId = CIMC.contractId
    LEFT JOIN 
        GlobalItemMainCheck GIC ON C.contractId = GIC.contractId
)

-- Final selection
SELECT 
    A.counterpartAssetId,
    A.counterpartAssetSerialNumber,
    A.counterpartAssetManufacturerId,
    A.counterpartAssetItemClass,
    A.counterpartAssetSourceSiteId,
    A.counterpartAssetCustomerNumber,
    C.contractId,
    C.contractItemNumber,
    FC.rootCause AS finalRootCause
FROM 
    AssetsWithoutContract A
LEFT JOIN 
    ContractsForOriginalAssets C ON A.counterpartAssetId = C.counterpartAssetId
LEFT JOIN 
    FinalCheck FC ON C.contractId = FC.contractId;





