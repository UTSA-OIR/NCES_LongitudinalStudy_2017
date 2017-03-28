  /*
   Keywords: NCES, Student Records, Comma Seperated file spec
   What does the query do?: 
   
   Uses spriden to find all student PIDMS and merges the key information needed for the NCES study onto the file
   
   
   
   When was it last updated?: 3/22/2017
   Other notes regarding this syntax or request?:
   

   
  */



SELECT 1 AS FileSpecVers,

--change to your Institutional ID
       111111 AS InstituteID,
--decode below is based on the excel file and uses PIDM to decode into the Study ID, this was created internally to decode file
       DECODE (RAVEN.SPRIDEN.SPRIDEN_PIDM,
            123456789,01234567)
          AS StudyID,
          --get identifying information from SPRIDEN
       SPRIDEN_PIDM AS StudentID,
       SPRIDEN_FIRST_NAME AS Firstname,
       SPRIDEN_MI AS Middlename,
       SPRIDEN_LAST_NAME AS Lastname,
       RAVEN.SPBPERS.SPBPERS_NAME_SUFFIX AS Suffix_,
       RAVEN.SPBPERS.SPBPERS_SSN AS SSN,
       --Use extract to get month, day and year from Birthdate
       EXTRACT (MONTH FROM RAVEN.SPBPERS.SPBPERS_BIRTH_DATE) AS DOB_month,
       EXTRACT (DAY FROM RAVEN.SPBPERS.SPBPERS_BIRTH_DATE) AS DOB_day,
       EXTRACT (YEAR FROM RAVEN.SPBPERS.SPBPERS_BIRTH_DATE) AS DOB_year,
       --Decode M and F into the 0 (male) and 1 (female) as needed for NCES file 
       NVL (DECODE (RAVEN.SPBPERS.SPBPERS_SEX,  'M', 0,  'F', 1), -1) AS Sex,
      --Decode S (single) and M (married) into the 0 (Single) and 1 (married) as needed for NCES file 
       NVL (DECODE (RAVEN.SPBPERS.SPBPERS_MRTL_CODE,  'S', 0,  'M', 1), -1)
          AS MaritialStatus,
      --Placeholders since these data are not available in our system
       '' AS MaidenName,
       '' AS SpouseFname,
       '' AS SpouseMname,
       '' AS SpouseLname,
       
       --Set up citizenship status based on visa type in GORVISA and citizenship code in SPBPERS
       
       CASE
          WHEN     GORVISA_VTYP_CODE = 'PR'
               AND GORVISA_VISA_EXPIRE_DATE >
                      TO_DATE ('2017-01-01', 'YYYY-MM-DD')
          THEN
             2
          ELSE
             DECODE (RAVEN.SPBPERS.SPBPERS_CITZ_CODE,
                     'Y', 1,
                     'N', 3,
                     'U', -1)
       END
          AS CitizenStatus,
          
          
       --veteran table is based on a set of tables that contains information on veteran funding at UTSA
       --see query for details on this one
          
          
          
       NVL (Veteran, 0) AS VeteranStatus,
       

       /*Look at the SORHSCH table and parse out the high school gradution codes (6SEM and GRAD) to set up indicator to show
       HS graduation, GED or Homeschool
       */
       
       CASE
          WHEN     SORHSCH_ADMR_CODE IN ('GRAD', '6SEM')
               AND SORHSCH_SBGI_CODE <> 'H77777'
          THEN
             1
          WHEN SORHSCH_ADMR_CODE IN ('GED')
          THEN
             2
          WHEN SORHSCH_SBGI_CODE = 'H77777'
          THEN
             4
          WHEN STVSBGI_DESC = 'Unknown' OR STVSBGI_DESC IS NULL
          THEN
             -1
          WHEN STVSBGI_DESC IS NOT NULL
          THEN
             1
          ELSE
             -99
       END
          AS HighSchoolType,
          
       
       
       /*Get Year from high school graduation date, note there are many blanks here due to missing data in the SORHSCH file*/
       
       EXTRACT (YEAR FROM SORHSCH_GRADUATION_DATE) AS GraduationYear,
       
       /*decode hispanic students based on the Ethncde in SPBPERS, 2 is hispanic, 1 is not hispanic*/
       
       DECODE (Race_Ethnic_Q.SPBPERS_ETHN_CDE,  2, 1,  1, 0) AS Ethnicity,
       
       /*For race if the field is not null then it means they are the specified race, most hispanic students do not have 
       a race indicated so there are many errors here in the NCES error handler
       */
       
       CASE WHEN Race_Ethnic_Q.White IS NOT NULL THEN 1 END AS white,
       CASE WHEN Race_Ethnic_Q.Black IS NOT NULL THEN 1 END AS black,
       CASE WHEN Race_Ethnic_Q.asian IS NOT NULL THEN 1 END AS asian,
       CASE WHEN Race_Ethnic_Q.amerind IS NOT NULL THEN 1 END  AS americanindian,
       CASE WHEN Race_Ethnic_Q.NativeHAW IS NOT NULL THEN 1 END AS nativehaw,
       
       --get permanent address broken out, see query permaddr_q for details on the source
       
       permaddr_Q.SPRADDR_STREET_LINE1 AS PermLine1,
       permaddr_Q.SPRADDR_STREET_LINE2 || permaddr_Q.SPRADDR_STREET_LINE3 AS PermLine2,
       permaddr_Q.SPRADDR_CITY AS PermCity,
       permaddr_Q.SPRADDR_STAT_CODE AS PermState,
       permaddr_Q.SPRADDR_ZIP,
       permaddr_Q.SPRADDR_NATN_CODE,
       
       --residence code based on the latest entry in SGBSTDN table and convert to NCES values
       
       CASE
          WHEN SGBSTDN_RESD_CODE IN ('1', 'B') THEN 1
          WHEN SGBSTDN_RESD_CODE IN ('6', 'M', '2') THEN 0
          WHEN SGBSTDN_RESD_CODE IS NULL THEN -1
          ELSE -99
       END
          AS ResidentofState,

       --get mailing/local address broken out, see query permaddr_q for details on the source
          
       MailingAddr_Q.SPRADDR_STREET_LINE1 AS MailLine1,
          MailingAddr_Q.SPRADDR_STREET_LINE2
       || MailingAddr_Q.SPRADDR_STREET_LINE3
          AS MailLine2,
       MailingAddr_Q.SPRADDR_CITY AS MailCity,
       MailingAddr_Q.SPRADDR_STAT_CODE AS MailState,
       MailingAddr_Q.SPRADDR_ZIP AS MailZip,
       
       --get phone numbers and combine area and number, see LocalPhone_Q query for details on the source
       
       LocalPhone_Q.SPRTELE_PHONE_AREA || LocalPhone_Q.SPRTELE_PHONE_NUMBER
          AS Phone1Number,
       1 AS Phone1Type,
       permphone_q.SPRTELE_PHONE_AREA || permphone_q.SPRTELE_PHONE_NUMBER
          AS Phone2Number,
       1 AS Phone2Type,
       
       --email addresses come from GOREMAL, but different queries (CampusEmail_Q,PreferredEmail_Q) to get logic for each type
              
       CampusEmail_Q.CAMPUSEMAILADDRESS,
       PreferredEmail_Q.PreferredEmailAddress,
       
       --These are not available in our system so they are placeholders, the -1 is set up to avoid errors.
       '' AS ParentFirstName,
       '' AS ParentMiddleName,
       '' AS ParentLastName,
       '' AS ParentSuffix,
       '' AS ParentAddressLine1,
       '' AS ParentAddressLine2,
       '' AS ParentAddressCity,
       '' AS ParentAddressStateorProvince,
       '' AS ParentAddressZip,
       '' AS ParentCountry_ifnotUSA,
       '' AS ParentEmail,
       '' AS ParentPhone,
       '' AS ParentCellPhone,
       '' AS ParentInternationalPhone,
       '' AS OtherContactFirstName,
       '' AS OtherContactMiddleName,
       '' AS OtherContactLastName,
       '' AS OtherContactSuffix,
       -1 AS RelOtherContacttoStudent,
       '' AS OtherContactAddressLine1,
       '' AS OtherContactAddressLine2,
       '' AS OtherContactAddressCity,
       '' AS OthContAddrStateorProvince,
       '' AS OtherContactAddressZip,
       '' AS OthConCountryifnotUSA,
       '' AS OtherContactEmail,
       '' AS OtherPhone,
       '' AS OtherCellPhone,
       '' AS AdditionalContactFirstName,
       '' AS AdditionalContactMiddleName,
       '' AS AdditionalContactLastName,
       '' AS AdditionalContactSuffix,
       '' AS AdditionalPhone,
       -1 AS RelAddlContacttoStudent
FROM raven.spriden

--join SPBPERS to get citizenship and SSN, could also be done by the race/ethnic query further down
     LEFT JOIN RAVEN.SPBPERS
       ON RAVEN.SPRIDEN.SPRIDEN_PIDM = RAVEN.SPBPERS.SPBPERS_PIDM
       
       
--Find the most recent visa code and use this to determine if the student had a visa (most are PR)
       
       
     LEFT JOIN
     (SELECT GORVISA_PIDM, GORVISA_VTYP_CODE, GORVISA_VISA_EXPIRE_DATE
      FROM (SELECT GORVISA_PIDM,
                   GORVISA_VTYP_CODE,
                   GORVISA_VISA_EXPIRE_DATE,
                   ROW_NUMBER ()
                   OVER (PARTITION BY GORVISA_PIDM
                         ORDER BY GORVISA_SEQ_NO DESC)
                      RowSelect
            FROM RAVEN.GORVISA)
      WHERE RowSelect = 1) mostrecentvisa_Q
        ON RAVEN.SPRIDEN.SPRIDEN_PIDM = mostrecentvisa_Q.GORVISA_PIDM
        
/*the set of tables below are veteran indicators and are all unioned together to make one table which has all of the veterans, 
this is then merged on PIDM with the dataset to see if they are a veteran*/
        
     LEFT JOIN
     (SELECT DISTINCT TBRACCD.TBRACCD_PIDM AS VeteranPIDM, 1 AS Veteran
      FROM TBRACCD
      WHERE     TBRACCD.TBRACCD_DETAIL_CODE = 'EX21'
            AND TBRACCD.TBRACCD_AMOUNT > 0
      UNION
      SELECT DISTINCT SGRVETN.SGRVETN_PIDM AS VeteranPIDM, 1 AS Veteran
      FROM SGRVETN
      WHERE SGRVETN_VETC_CODE IN ('0',
                                  '1',
                                  '2',
                                  '4',
                                  '6',
                                  '7',
                                  '9',
                                  'P')
      UNION
      SELECT DISTINCT RE_SGRSATT_PIDM AS VeteranPIDM, 1 AS Veteran
      FROM RAVEN.RE_SGRSATT
      WHERE RE_SGRSATT_ATTS_CODE = 'VFOR') Veterans_Q
        ON RAVEN.SPRIDEN.SPRIDEN_PIDM = Veterans_Q.VeteranPIDM
        
/*Find the most recent high school activity date and use this record to determine the high school status
also checking pidm by pidm for missing grad dates, transfer students will not have grad dates so that is problematic
for NCES error checking
*/        
        
        
     LEFT JOIN
     (SELECT SORHSCH_PIDM,
             SORHSCH_SBGI_CODE,
             STVSBGI_DESC,
             SORHSCH_GRADUATION_DATE,
             SORHSCH_DPLM_CODE,
             SORHSCH_ADMR_CODE
      FROM (SELECT SORHSCH_PIDM,
                   SORHSCH_SBGI_CODE,
                   RAVEN.STVSBGI.STVSBGI_DESC,
                   SORHSCH_GRADUATION_DATE,
                   SORHSCH_DPLM_CODE,
                   SORHSCH_ADMR_CODE,
                   ROW_NUMBER ()
                   OVER (PARTITION BY SORHSCH_PIDM
                         ORDER BY SORHSCH_ACTIVITY_DATE DESC)
                      RowSelect
            FROM RAVEN.SORHSCH
                 LEFT JOIN RAVEN.STVSBGI
                    ON RAVEN.SORHSCH.SORHSCH_SBGI_CODE =
                          RAVEN.STVSBGI.STVSBGI_CODE)
      WHERE RowSelect = 1) Highschool_q
        ON RAVEN.SPRIDEN.SPRIDEN_PIDM = Highschool_q.SORHSCH_PIDM
        
        

/*Race Ethnicity calculation based on GORPRAC and SPBPERS for new codes*/                
        
     LEFT JOIN
     ( /*
        Keywords: Race/Ethnicity/IPEDS Conversion
        What does the query do?:  Flattens GORRACE accross columns to remove duplicates
        When was it last updated?: 3/17/2015
       * Other notes regarding this syntax or request?:.


       */
      SELECT SPBPERS.SPBPERS_PIDM,
             SPBPERS.SPBPERS_ETHN_CDE,
              SPBPERS.SPBPERS_CITZ_IND, SPBPERS.SPBPERS_CITZ_CODE,
             DECODE (SPBPERS.SPBPERS_SEX,  'M', 'Male',  'F', 'Female')
                AS Gender,
             unknown.GORRACE_DESC AS Unknown,
             amind.GORRACE_DESC AS AmerInd,
             asian.GORRACE_DESC AS Asian,
             black.GORRACE_DESC AS Black,
             nativehaw.GORRACE_DESC AS NativeHaw,
             white.GORRACE_DESC AS White,
             intl.GORRACE_DESC AS Intl,
             DECODE (
                CASE
                   WHEN intl.GORRACE_DESC IS NOT NULL
                   THEN
                      '6'
                   WHEN SPBPERS_ETHN_CDE = '2'
                   THEN
                      '3'
                   WHEN LENGTH (
                              amind.GORPRAC_RACE_CDE
                           || asian.GORPRAC_RACE_CDE
                           || black.GORPRAC_RACE_CDE
                           || nativehaw.GORPRAC_RACE_CDE
                           || white.GORPRAC_RACE_CDE) > 1
                   THEN
                      '9'
                   WHEN white.GORRACE_DESC IS NOT NULL
                   THEN
                      '1'
                   WHEN black.GORRACE_DESC IS NOT NULL
                   THEN
                      '2'
                   WHEN asian.GORRACE_DESC IS NOT NULL
                   THEN
                      '4'
                   WHEN amind.GORRACE_DESC IS NOT NULL
                   THEN
                      '5'
                   WHEN nativehaw.GORRACE_DESC IS NOT NULL
                   THEN
                      '8'
                   ELSE
                      '7'
                END,
                1, 'White',
                2, 'Black or African-American ',
                3, 'Hispanic or Latino',
                4, 'Asian',
                5, 'American Indian or Alaskan Native',
                6, 'International',
                7, 'Unknown or Not Reported',
                8, 'Native Hawaiian or Other Pacific Islander Only',
                9, 'Two or More Races')
                AS IPEDS_RE
      FROM SPBPERS
           /*each of the joins below brings in one race and the international indicator*/

           LEFT JOIN
           (                                                       /*Unknown*/
            SELECT DISTINCT
                   GORPRAC.GORPRAC_PIDM,
                   GORRACE.GORRACE_DESC,
                   GORPRAC.GORPRAC_RACE_CDE
            FROM GORPRAC
                 LEFT JOIN GORRACE
                    ON GORPRAC.GORPRAC_RACE_CDE = GORRACE.GORRACE_RACE_CDE
            WHERE GORPRAC.GORPRAC_RACE_CDE = '0') unknown
              ON SPBPERS.SPBPERS_PIDM = unknown.GORPRAC_PIDM
           /*AmInd Ak Native*/
           LEFT JOIN
           (SELECT DISTINCT
                   GORPRAC.GORPRAC_PIDM,
                   GORRACE.GORRACE_DESC,
                   GORPRAC.GORPRAC_RACE_CDE
            FROM GORPRAC
                 LEFT JOIN GORRACE
                    ON GORPRAC.GORPRAC_RACE_CDE = GORRACE.GORRACE_RACE_CDE
            WHERE GORPRAC.GORPRAC_RACE_CDE = '1') amind
              ON SPBPERS.SPBPERS_PIDM = amind.GORPRAC_PIDM
           /*Asian*/
           LEFT JOIN
           (SELECT DISTINCT
                   GORPRAC.GORPRAC_PIDM,
                   GORRACE.GORRACE_DESC,
                   GORPRAC.GORPRAC_RACE_CDE
            FROM GORPRAC
                 LEFT JOIN GORRACE
                    ON GORPRAC.GORPRAC_RACE_CDE = GORRACE.GORRACE_RACE_CDE
            WHERE GORPRAC.GORPRAC_RACE_CDE = '2') asian
              ON SPBPERS.SPBPERS_PIDM = asian.GORPRAC_PIDM
           /*Black*/
           LEFT JOIN
           (SELECT DISTINCT
                   GORPRAC.GORPRAC_PIDM,
                   GORRACE.GORRACE_DESC,
                   GORPRAC.GORPRAC_RACE_CDE
            FROM GORPRAC
                 LEFT JOIN GORRACE
                    ON GORPRAC.GORPRAC_RACE_CDE = GORRACE.GORRACE_RACE_CDE
            WHERE GORPRAC.GORPRAC_RACE_CDE = '3') black
              ON SPBPERS.SPBPERS_PIDM = black.GORPRAC_PIDM
           /*Native Hawaiian*/
           LEFT JOIN
           (SELECT DISTINCT
                   GORPRAC.GORPRAC_PIDM,
                   GORRACE.GORRACE_DESC,
                   GORPRAC.GORPRAC_RACE_CDE
            FROM GORPRAC
                 LEFT JOIN GORRACE
                    ON GORPRAC.GORPRAC_RACE_CDE = GORRACE.GORRACE_RACE_CDE
            WHERE GORPRAC.GORPRAC_RACE_CDE = '4') nativehaw
              ON SPBPERS.SPBPERS_PIDM = nativehaw.GORPRAC_PIDM
           /*White*/

           LEFT JOIN
           (SELECT DISTINCT
                   GORPRAC.GORPRAC_PIDM,
                   GORRACE.GORRACE_DESC,
                   GORPRAC.GORPRAC_RACE_CDE
            FROM GORPRAC
                 LEFT JOIN GORRACE
                    ON GORPRAC.GORPRAC_RACE_CDE = GORRACE.GORRACE_RACE_CDE
            WHERE GORPRAC.GORPRAC_RACE_CDE = '5') white
              ON SPBPERS.SPBPERS_PIDM = white.GORPRAC_PIDM
           /*Intl*/

           LEFT JOIN
           (SELECT DISTINCT
                   GORPRAC.GORPRAC_PIDM,
                   GORRACE.GORRACE_DESC,
                   GORPRAC.GORPRAC_RACE_CDE
            FROM GORPRAC
                 LEFT JOIN GORRACE
                    ON GORPRAC.GORPRAC_RACE_CDE = GORRACE.GORRACE_RACE_CDE
            WHERE GORPRAC.GORPRAC_RACE_CDE = '6') intl
              ON SPBPERS.SPBPERS_PIDM = intl.GORPRAC_PIDM) Race_Ethnic_Q
        ON RAVEN.SPRIDEN.SPRIDEN_PIDM = Race_Ethnic_Q.SPBPERS_PIDM
        
        
  /*Find the most recent permanent address on file for each student*/                
      
        
     LEFT JOIN
     (SELECT SPRADDR_PIDM,
             SPRADDR_STREET_LINE1,
             SPRADDR_STREET_LINE2,
             SPRADDR_STREET_LINE3,
             SPRADDR_CITY,
             SPRADDR_STAT_CODE,
             SPRADDR_ZIP,
             SPRADDR_CNTY_CODE,
             SPRADDR_NATN_CODE
      FROM (SELECT SPRADDR_PIDM,
                   SPRADDR_STREET_LINE1,
                   SPRADDR_STREET_LINE2,
                   SPRADDR_STREET_LINE3,
                   SPRADDR_CITY,
                   SPRADDR_STAT_CODE,
                   SPRADDR_ZIP,
                   SPRADDR_CNTY_CODE,
                   SPRADDR_NATN_CODE,
                   SPRADDR_SEQNO,
                   ROW_NUMBER ()
                   OVER (PARTITION BY SPRADDR_PIDM
                         ORDER BY SPRADDR_SEQNO DESC)
                      RowSelect
            FROM RAVEN.SPRADDR
            WHERE SPRADDR_ATYP_CODE = 'PR')
      WHERE RowSelect = 1) permaddr_Q
        ON RAVEN.SPRIDEN.SPRIDEN_PIDM = permaddr_Q.SPRADDR_PIDM
        
/*Find the most recent mailing/local address on file for each student*/                        
        
     LEFT JOIN
     (SELECT SPRADDR_PIDM,
             SPRADDR_STREET_LINE1,
             SPRADDR_STREET_LINE2,
             SPRADDR_STREET_LINE3,
             SPRADDR_CITY,
             SPRADDR_STAT_CODE,
             SPRADDR_ZIP,
             SPRADDR_CNTY_CODE,
             SPRADDR_NATN_CODE
      FROM (SELECT SPRADDR_PIDM,
                   SPRADDR_STREET_LINE1,
                   SPRADDR_STREET_LINE2,
                   SPRADDR_STREET_LINE3,
                   SPRADDR_CITY,
                   SPRADDR_STAT_CODE,
                   SPRADDR_ZIP,
                   SPRADDR_CNTY_CODE,
                   SPRADDR_NATN_CODE,
                   SPRADDR_SEQNO,
                   ROW_NUMBER ()
                   OVER (PARTITION BY SPRADDR_PIDM
                         ORDER BY SPRADDR_SEQNO DESC)
                      RowSelect
            FROM RAVEN.SPRADDR
            WHERE SPRADDR_ATYP_CODE = 'MA')
      WHERE RowSelect = 1) MailingAddr_Q
        ON RAVEN.SPRIDEN.SPRIDEN_PIDM = MailingAddr_Q.SPRADDR_PIDM
        
/*Join SGBSTDN tp get the residence code for each student to determine if the were in state*/                        
        
        
     LEFT JOIN
     (SELECT SGBSTDN_PIDM, SGBSTDN_RESD_CODE
      FROM (SELECT SGBSTDN_PIDM,
                   SGBSTDN_RESD_CODE,
                   ROW_NUMBER ()
                   OVER (PARTITION BY SGBSTDN_PIDM
                         ORDER BY SGBSTDN_TERM_CODE_EFF DESC)
                      RowSelect
            FROM RAVEN.SGBSTDN)
      WHERE RowSelect = 1) sgbstdn_resd_q
        ON SPRIDEN_PIDM = sgbstdn_resd_q.SGBSTDN_PIDM
        
/*Join SPRTELE table to get most recent telephone code that is listed as Local (MA) exclude unlisted numbers*/                                
        
     LEFT JOIN
     (SELECT SPRTELE_PIDM, SPRTELE_PHONE_AREA, SPRTELE_PHONE_NUMBER
      FROM (SELECT SPRTELE_PIDM,
                   SPRTELE_ACTIVITY_DATE,
                   SPRTELE_PHONE_AREA,
                   SPRTELE_PHONE_NUMBER,
                   SPRTELE_PHONE_EXT,
                   SPRTELE_CTRY_CODE_PHONE,
                   ROW_NUMBER ()
                   OVER (PARTITION BY SPRTELE_PIDM
                         ORDER BY SPRTELE_SEQNO DESC)
                      RowSelect
            FROM sprtele
            WHERE     (SPRTELE_UNLIST_IND IS NULL OR SPRTELE_UNLIST_IND = 'N')
                  AND SPRTELE_TELE_CODE IN ('MA'))
      WHERE Rowselect = 1) LocalPhone_Q
        ON RAVEN.SPRIDEN.SPRIDEN_PIDM = LocalPhone_Q.SPRTELE_PIDM
        
        /*Join SPRTELE table to get most recent telephone code that is listed as permanent (PR) exclude unlisted numbers*/                                

        
     LEFT JOIN
     (SELECT SPRTELE_PIDM, SPRTELE_PHONE_AREA, SPRTELE_PHONE_NUMBER
      FROM (SELECT SPRTELE_PIDM,
                   SPRTELE_ACTIVITY_DATE,
                   SPRTELE_PHONE_AREA,
                   SPRTELE_PHONE_NUMBER,
                   SPRTELE_PHONE_EXT,
                   SPRTELE_CTRY_CODE_PHONE,
                   ROW_NUMBER ()
                   OVER (PARTITION BY SPRTELE_PIDM
                         ORDER BY SPRTELE_SEQNO DESC)
                      RowSelect
            FROM sprtele
            WHERE     (SPRTELE_UNLIST_IND IS NULL OR SPRTELE_UNLIST_IND = 'N')
                  AND SPRTELE_TELE_CODE IN ('PR'))
      WHERE Rowselect = 1) permphone_q
        ON RAVEN.SPRIDEN.SPRIDEN_PIDM = permphone_q.SPRTELE_PIDM
        
        
         /*Join GOREMAL table to get campus email (ending in our domain)*/                                
       
        
     LEFT JOIN
     (SELECT GOREMAL_PIDM, CAMPUSEMAILADDRESS
      FROM (SELECT GOREMAL_PIDM,
                   GOREMAL_ACTIVITY_DATE,
                   LOWER (GOREMAL_EMAIL_ADDRESS) AS CampusEmailAddress,
                   ROW_NUMBER ()
                   OVER (PARTITION BY GOREMAL_PIDM
                         ORDER BY GOREMAL_ACTIVITY_DATE DESC)
                      RowSelect
            FROM GOREMAL
            WHERE     LOWER (GOREMAL_EMAIL_ADDRESS) LIKE '%@my.utsa.edu'
                  AND GOREMAL_STATUS_IND = 'A')
      WHERE RowSelect = 1) CampusEmail_Q
        ON RAVEN.SPRIDEN.SPRIDEN_PIDM = CampusEmail_Q.GOREMAL_PIDM
        
         /*Join GOREMAL table to get preffered active email */                                
        
        
     LEFT JOIN
     (SELECT GOREMAL_PIDM, PreferredEmailAddress
      FROM (SELECT GOREMAL_PIDM,
                   GOREMAL_ACTIVITY_DATE,
                   LOWER (GOREMAL_EMAIL_ADDRESS) AS PreferredEmailAddress,
                   ROW_NUMBER ()
                   OVER (PARTITION BY GOREMAL_PIDM
                         ORDER BY GOREMAL_ACTIVITY_DATE DESC)
                      RowSelect
            FROM GOREMAL
            WHERE GOREMAL_STATUS_IND = 'A' AND GOREMAL_PREFERRED_IND = 'Y')
      WHERE RowSelect = 1) PreferredEmail_Q
        ON RAVEN.SPRIDEN.SPRIDEN_PIDM = PreferredEmail_Q.GOREMAL_PIDM

         /*Select only the PIDMS that are included in this study*/                                
        
        
WHERE     SPRIDEN_PIDM IN (123456789)
      AND SPRIDEN_CHANGE_IND IS NULL