file="talos/argoApps/cert-manager.yaml"
if [ $(yq e 'has(".spec.template.spec.sources[*]")' "$file") == 'true' ]
then
    echo -e "[ INFO ] > Application has single source"
else
    echo "multiple"

fi