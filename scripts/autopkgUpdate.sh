#!/bin/sh
#
#
#Copyright 2020 Eric Pomelow
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.
#
# Run autopkg task to update repos, update trust info, and run each recipe.
# Recipe list and all required repos must already be installed

#autopkg binary
autopkgBin="/usr/local/bin/autopkg"

#update AutoPkg RecipeRepos
"$autopkgBin" repo-update all

#update trust info for AutoPkg
while read i
  do
    "$autopkgBin" update-trust-info "$i"

    #run autopkg recipes
    "$autopkgBin" run "$i"

done < "/Users/usitadmin/Library/Application Support/AutoPkgr/recipe_list.txt"

exit 0
