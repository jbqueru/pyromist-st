/*
 *  Copyright 2020 Jean-Baptiste M. "JBQ" "Djaybee" Queru
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#include <stdio.h>
#include <math.h>

int main() {
	int i;
	printf(
		";   Copyright 2020 Jean-Baptiste M. \"JBQ\" \"Djaybee\" Queru\n"
		";\n"
		";   Licensed under the Apache License, Version 2.0 (the \"License\");\n"
		";   you may not use this file except in compliance with the License.\n"
		";   You may obtain a copy of the License at\n"
		";\n"
		";       http://www.apache.org/licenses/LICENSE-2.0\n"
		";\n"
		";   Unless required by applicable law or agreed to in writing, software\n"
		";   distributed under the License is distributed on an \"AS IS\" BASIS,\n"
		";   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n"
		";   See the License for the specific language governing permissions and\n"
		";   limitations under the License.\n"
		"\n"
		"; This file is generated, do not modify. See gen_sin.c\n"
		"\n");
	printf("sin_table_1024_16384:\n\tdc.w ");
	for (i=0;i<1024;i++) {
		printf("%d",(int)(16384*sin(2*M_PI*i/1024)));
		if ((i&7)==7) {
			printf("\n");
			if (i!=1023) {
				printf("\tdc.w ");
			}
		} else {
			printf(",");
		}
	}
	return 0;
}
