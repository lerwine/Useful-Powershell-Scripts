cls;
$Source = "C:\Users\erwinele_adm.ISEDLAB.001\Documents\RoleAndFeatureIdentifiers.xml";
$Stylesheet = "C:\Users\erwinele_adm.ISEDLAB.001\Documents\RoleAndFeatureIdentifiersFlatDoc.xslt";
$Output = "C:\Users\erwinele_adm.ISEDLAB.001\Documents\RoleAndFeatureIdentifiersFlatDoc.html";
$myXslTrans = New-Object System.Xml.Xsl.XslCompiledTransform; 
$myXslTrans.Load($Stylesheet); 
$myXslTrans.Transform($Source,$Output); 
Get-Content -Path:$Output;
