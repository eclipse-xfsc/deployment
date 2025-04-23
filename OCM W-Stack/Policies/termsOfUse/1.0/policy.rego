package Policies.termsOfUse

result = getTerms(input)

getTerms(i) = res {
	res := data.terms[i.tenant][i.group]
}