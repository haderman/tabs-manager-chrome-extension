

# Woki
<p>
  <a href="https://github.com/haderman/woki-extension/blob/master/LICENSE">
    <img src="https://img.shields.io/github/license/haderman/woki-extension" alt="Woki is released under the MIT license." />
  </a>
  <a href="https://github.com/haderman/woki-extension/graphs/commit-activity">
    <img src="https://img.shields.io/github/last-commit/haderman/woki-extension" alt="Last commit" />
  </a>
</p>

Esto es una extensión para navegadores basados en Chromium, esto incluye [Brave](https://brave.com/) and [Chrome](https://www.google.com/intl/es-419/chrome/).


Esta extensión permite hasta ahora:

 - Agrupar tabs y asignarle un nombre, ese grupo es llamado Workspace
 - Abrir un workspace, esto signigica reemplazar las pestañas abiertas por las pestañas del workspace que se quiere abrir
 - Eliminar workspaces
 - Abrir una pestaña individual desde la pagina de newtab


# Tabla de contenido
1. [Build](#build)   
2. [Dev](#dev)
3. [Licencia](#licence) 


<a name="build"></a> 
# Build
Tener en cuenta que esta applicación usa [Deno](https://deno.land). Dicho esto, para hacer el build deber solo debes ejecutar:

    sh build.sh

Este comando crea la carpeta `dist` que se puede cargar en el navegador como una extensión sin empaquetar

<a name="dev"></a> 
# Dev
Tener en cuenta que esta applicación usa

 - [Deno](https://deno.land) como alternativa a [nodejs](https://nodejs.org/es/)
 - [Denon](https://deno.land/x/denon/) como alternativa a [nodemon](https://www.npmjs.com/package/nodemon)
 - [Elm](https://elm-lang.org/) cómo alternativa a javascript

El script [dev.sh](https://github.com/haderman/woki-extension/blob/master/dev.sh) contiene los comandos para observar cambios en archivos y crear los bundles, según el párametro enviado
```
sh dev.sh newtab|popup|background
```
Dependiendo el párametro se observan los cambios en los archivos y se crea los bundles

<a name="licence"></a> 
# Licencia
Licensed under the [MIT License](LICENCE.md)



