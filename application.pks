CREATE OR REPLACE PACKAGE application IS
  FUNCTION GetSplittedText
    (
      pis_ParameterString  VARCHAR2,
      pis_Delimiter        VARCHAR2,
      pin_ParameterNo      NUMBER
    ) RETURN VARCHAR2 ;
  
  PROCEDURE i_Operations
    (
      pis_InsertUser  selim_application.insert_user%TYPE DEFAULT NULL
    );
  
	PROCEDURE ExecuteWebService
    (
      pin_id          NUMBER,
      pin_number_1    NUMBER,
      pin_number_2    NUMBER,
      pis_operation   VARCHAR2,
      pon_result      OUT NUMBER,
      pos_statusCode  OUT VARCHAR2,
      poc_xmlResponse OUT CLOB
	  );  
  
  PROCEDURE ManualExecute
    (
      pis_IdList      VARCHAR2, 
      pis_ModifyUser  selim_application.modify_user%TYPE DEFAULT NULL
    );
  
  PROCEDURE Main
    (
      pis_ModifyUser  selim_application.modify_user%TYPE DEFAULT NULL
    );

END application;
/
