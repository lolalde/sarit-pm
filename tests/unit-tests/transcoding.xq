xquery version "3.0";

import module namespace sarit-slp1 = "http://hra.uni-heidelberg.de/ns/sarit-transliteration";

<results>
	<result>roman to SLP1: sukhena => {sarit-slp1:transcode("sukhena")}</result>
	<result>devanagari to SLP1: सुखेन =>  {sarit-slp1:transcode("सुखेन")}</result>
	<result>roman with wildcard to SLP1: paramā* => {sarit-slp1:transcode("paramā*")}</result>	
</results>
