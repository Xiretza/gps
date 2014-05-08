/**
 * A namespace that contains all the information generated by the compiler. See
 * the documentation of the fields below.
 *
 * @constructor
 */

function GNATdoc() {}

/**
 * Possible kinds for entities
 * @enum {string}
 */
GNATdoc.EntityKind = {
   CODE: 'code',
   PARAGRAPH: 'paragraph',
   UL: 'ul',
   LI: 'li',
   SPAN: 'span',
   IMAGE: 'image'
};

/**
 * The data for main page
 * @typedef {{project:string, timestamp:string}}
 */
GNATdoc.Index;

/**
 * The data that describes an entity
 * @typedef {{line: {number:Number},
 *            column: {number:Number},
 *            href: string,
 *            text: string,
 *            cssClass: string,
 *            kind: GNATdoc.EntityKind,
 *            children: Array.<GNATdoc.Entity>}}
 */
GNATdoc.Entity;

/**
 * ???
 * @type {{label:string, summary:string, entities:Array.<GNATdoc.Entity>, description:string}}
 */
GNATdoc.Documentation;

/**
 * ???
 * @type {Array}
 */
GNATdoc.DocumentationIndex = [];

/**
 * ???
 * @type {Array}
 */
GNATdoc.EntitiesCategoriesIndex = [];

/**
 * ???
 * @type {Array}
 */
GNATdoc.EntitiesCategory = [];

/**
 * ???
 * @type {Array}
 */
GNATdoc.InheritanceIndex = [];

/**
 * ???
 * @type {Array}
 */
GNATdoc.SourceFile = [];

/**
 * ???
 * @type {Array}
 */
GNATdoc.SourceFileIndex = [];

/**
 * ???
 *
 * @param {Element} root  The element to which we add the documentation.
 * @param {Array.<GNATdoc.Entity>} data    The data to convert.
 */

function buildText(root, data) {
   /** @type {Element} */
   var element;

   for (var index = 0; index < data.length; index++) {
       switch (data[index].kind) {
           case GNATdoc.EntityKind.CODE:
               element = document.createElement('table');
               element.className = 'code';
               element.cellPadding = 0;
               element.cellSpacing = 0;
               var code = document.createElement('tbody');

               for (var lineIndex = 0;
                    lineIndex < data[index].children.length;
                    lineIndex++)
               {
                   var line = data[index].children[lineIndex];
                   var row = document.createElement('tr');
                   var cell = document.createElement('th');
                   cell.id = 'L' + line.number.toString();
                   cell.appendChild(document.createTextNode(line.number));
                   row.appendChild(cell);
                   cell = document.createElement('td');
                   buildText(cell, line.children);
                   row.appendChild(cell);
                   code.appendChild(row);
               }

               element.appendChild(code);
               break;

           case GNATdoc.EntityKind.PARAGRAPH:
               element = document.createElement('p');
               buildText(element, data[index].children);
               break;

           case GNATdoc.EntityKind.UL:
               element = document.createElement('ul');
               buildText(element, data[index].children);
               break;

           case GNATdoc.EntityKind.LI:
               element = document.createElement('li');
               buildText(element, data[index].children);
               break;

           case GNATdoc.EntityKind.SPAN:
               element = document.createElement('span');

               if (data[index].href !== undefined) {
                   var a = document.createElement('a');
                   a.href = '../' + data[index].href;
                   a.appendChild(document.createTextNode(data[index].text));
                   element.appendChild(a);

               } else {
                   element.appendChild(
                     document.createTextNode(data[index].text));
               }

               if (data[index].cssClass !== undefined) {
                  element.className = data[index].cssClass;
               }

               break;

           case GNATdoc.EntityKind.IMAGE:
               element = document.createElement('img');
               element.src = data[index].src;

               break;

       }
       root.appendChild(element);
   }
}

/**
 * ???
 */

function buildDocumentationPage() {
    var pane = document.getElementById('body');

    /* Build 'Summary' section */

    var header = document.createElement('h1');
    var text = document.createTextNode(GNATdoc.Documentation.label);
    header.appendChild(text);
    pane.appendChild(header);
    buildText(pane, GNATdoc.Documentation.summary);
    var a = document.createElement('a');
    a.href = '#Description';
    text = document.createTextNode('More...');
    a.appendChild(text);
    pane.appendChild(a);

    /* Build 'Entities' section */

    header = document.createElement('h2');
    text = document.createTextNode('Entities');
    header.appendChild(text);
    pane.appendChild(header);

    for (var index = 0; index < GNATdoc.Documentation.entities.length; index++)
    {
        var entity_set = GNATdoc.Documentation.entities[index];

        header = document.createElement('h3');
        text = document.createTextNode(entity_set.label);
        header.appendChild(text);
        pane.appendChild(header);

        var table = document.createElement('table');
        table.className = 'entities';
        table.cellPadding = 0;
        table.cellSpacing = 0;
        var tbody = document.createElement('tbody');

        for (var eindex = 0; eindex < entity_set.entities.length; eindex++) {
            var entity = entity_set.entities[eindex];
            var row = document.createElement('tr');
            var cell = document.createElement('th');
            var href = document.createElement('a');

            if (entity.href !== undefined) {
               href.href = entity.href;
            } else {
               href.href = '#L' + entity.line.toString() +
                  'C' + entity.column.toString();
            }

            href.appendChild(document.createTextNode(entity.label));
            cell.appendChild(href);
            row.appendChild(cell);
            cell = document.createElement('td');
            buildText(cell, entity.summary);
            row.appendChild(cell);
            tbody.appendChild(row);
        }

        table.appendChild(tbody);
        pane.appendChild(table);
    }

    /* Build 'Description' section */

    header = document.createElement('h2');
    header.id = 'Description';
    text = document.createTextNode('Description');
    header.appendChild(text);
    pane.appendChild(header);
    buildText(pane, GNATdoc.Documentation.description);

    /* Build entities description sections */

    for (var index = 0; index < GNATdoc.Documentation.entities.length; index++)
    {
        var entity_set = GNATdoc.Documentation.entities[index];

        for (var eindex = 0; eindex < entity_set.entities.length; eindex++) {
            var list = null;
            var entity = entity_set.entities[eindex];

            if (entity.href === undefined) {
                header = document.createElement('h3');
                header.id = 'L' + entity.line.toString() +
                  'C' + entity.column.toString();
                header.appendChild(document.createTextNode(entity.label));
                var sup = document.createElement('sup');
                sup.className = 'srcHref';
                href = document.createElement('a');
                href.href = '../' + entity.src +
                  '#L' + entity.line.toString();
                href.appendChild(document.createTextNode(' [source]'));
                sup.appendChild(href);
                header.appendChild(sup);
                pane.appendChild(header);
                buildText(pane, entity.description);

                if (entity.inherits !== undefined) {
                    var paragraph = document.createElement('p');
                    paragraph.appendChild(document.createTextNode('Inherits '));

                    for (var iindex = 0;
                         iindex < entity.inherits.length;
                         iindex++)
                    {
                        if (iindex != 0) {
                          paragraph.appendChild(document.createTextNode(', '));
                        }

                        if (entity.inherits[iindex].docHref === undefined) {
                          paragraph.appendChild(
                            document.createTextNode(
                              entity.inherits[iindex].label));

                        } else {
                           href = document.createElement('a');
                           href.href = '../' + entity.inherits[iindex].docHref;
                           href.target = 'contentView';
                           href.appendChild(
                             document.createTextNode(
                               entity.inherits[iindex].label));
                           paragraph.appendChild(href);
                        }
                    }

                    pane.appendChild(paragraph);
                }

                if (entity.inherited !== undefined) {
                    var paragraph = document.createElement('p');
                    paragraph.appendChild(
                      document.createTextNode('Inherited by '));

                    for (var iindex = 0;
                         iindex < entity.inherited.length;
                         iindex++)
                    {
                        if (iindex != 0) {
                          paragraph.appendChild(document.createTextNode(', '));
                        }

                        href = document.createElement('a');
                        href.href = '../' + entity.inherited[iindex].docHref;
                        href.target = 'contentView';
                        href.appendChild(
                          document.createTextNode(
                            entity.inherited[iindex].label));
                        paragraph.appendChild(href);
                    }

                    pane.appendChild(paragraph);
                }

                if (entity.parameters !== undefined) {
                    list = document.createElement('dl');

                    for (var pindex = 0;
                         pindex < entity.parameters.length;
                         pindex++)
                    {
                        var parameter = entity.parameters[pindex];
                        var term = document.createElement('dt');
                        term.id = 'L' + parameter.line.toString() +
                            'C' + parameter.column.toString();
                        term.appendChild(
                          document.createTextNode(parameter.label));
                        term.appendChild(
                          document.createTextNode(' of type '));
                        href = document.createElement('a');
                        href.href = '../' + parameter.type.docHref;
                        href.target = 'contentView';
                        href.appendChild(
                          document.createTextNode(parameter.type.label));
                        term.appendChild(href);

                        var description = document.createElement('dd');
                        buildText(description, parameter.description);

                        list.appendChild(term);
                        list.appendChild(description);
                    }
                }

                if (entity.returns !== undefined) {
                    list = list || document.createElement('dl');

                    var term = document.createElement('dt');
                    term.appendChild(document.createTextNode('Return value'));

                    if (entity.returns.type !== undefined) {
                        term.appendChild(document.createTextNode(' of type '));
                        href = document.createElement('a');
                        href.href = '../' + entity.returns.type.docHref;
                        href.target = 'contentView';
                        href.appendChild(
                          document.createTextNode(entity.returns.type.label));
                        term.appendChild(href);
                    }

                    var description = document.createElement('dd');
                    buildText(description, entity.returns.description);

                    list.appendChild(term);
                    list.appendChild(description);
                }

                if (entity.exceptions !== undefined) {
                   list = list || document.createElement('dl');

                   var term = document.createElement('dt');
                   term.appendChild(document.createTextNode('Exceptions'));
                   var description = document.createElement('dd');
                   buildText(description, entity.exceptions.description);

                   list.appendChild(term);
                   list.appendChild(description);
                }

                if (entity.fields !== undefined) {
                    list = document.createElement('dl');

                    for (var findex = 0;
                         findex < entity.fields.length;
                         findex++)
                    {
                        var field = entity.fields[findex];
                        var term = document.createElement('dt');
                        term.id = 'L' + field.line.toString() +
                            'C' + field.column.toString();
                        term.appendChild(
                          document.createTextNode(field.label));
                        term.appendChild(
                          document.createTextNode(' of type '));
                        href = document.createElement('a');
                        href.href = '../' + field.type.docHref;
                        href.target = 'contentView';
                        href.appendChild(
                          document.createTextNode(field.type.label));
                        term.appendChild(href);

                        var description = document.createElement('dd');
                        buildText(description, field.description);

                        list.appendChild(term);
                        list.appendChild(description);
                    }
                }

                //  For enumeration types generate description of each
                //  enumeration literal.

                if (entity.literals !== undefined) {
                    list = document.createElement('dl');

                    for (var lindex = 0;
                         lindex < entity.literals.length;
                         lindex++)
                    {
                        var literal = entity.literals[lindex];
                        var term = document.createElement('dt');
                        term.id = 'L' + literal.line.toString() +
                            'C' + literal.column.toString();
                        term.appendChild(
                          document.createTextNode(literal.label));

                        var description = document.createElement('dd');
                        buildText(description, literal.description);

                        list.appendChild(term);
                        list.appendChild(description);
                    }
                }

                if (list != null) {
                   pane.appendChild(list);
                }
            }
        }
    }
}

/**
 * ???
 * @param {Object} toc    ???.
 */

function buildPackagesIndex(toc) {
    var list = document.createElement('ul');

    toc.appendChild(list);

    for (var index = 0; index < GNATdoc.DocumentationIndex.length; index++)
    {
        var entry = GNATdoc.DocumentationIndex[index];
        var item = document.createElement('li');
        var href = document.createElement('a');

        href.href = entry.file;
        href.target = 'contentView';
        text = document.createTextNode(entry.label);
        href.appendChild(text);
        item.appendChild(href);
        list.appendChild(item);
    }

    list.style.display = 'none';
    list.id = 'packagesAndClasses';
}

/**
 * ???
 * @param {Object} toc    ???.
 */

function buildEntitiesCategoriesIndex(toc) {
    var list = document.createElement('ul');

    for (var idx = 0; idx < GNATdoc.EntitiesCategoriesIndex.length; idx++) {
        var item = document.createElement('li');
        var href = document.createElement('a');
        var entry = GNATdoc.EntitiesCategoriesIndex[idx];

        href.href = entry.href;
        href.target = 'contentView';
        href.appendChild(document.createTextNode(entry.label));
        item.appendChild(href);
        list.appendChild(item);
    }

    toc.appendChild(list);

    list.style.display = 'none';
    list.id = 'entities';
}

/**
 * ???
 * @param {Object} toc    ???.
 */

function buildSourcesIndex(toc) {
    var list = document.createElement('ul');

    for (var idx = 0; idx < GNATdoc.SourceFileIndex.length; idx++) {
        var source = GNATdoc.SourceFileIndex[idx];
        var item = document.createElement('li');
        var href = document.createElement('a');

        text = document.createTextNode(source.label);
        href.href = source.srcHref;
        href.target = 'contentView';
        href.appendChild(text);
        item.appendChild(href);
        list.appendChild(item);
    }

    toc.appendChild(list);

    list.style.display = 'none';
    list.id = 'sources';
}

/**
 * ???
 */

function buildEntitiesCategoryPage() {
    var header = document.createElement('h1');
    var character = '';
    var list = document.createElement('dl');
    var page = document.getElementById('body');

    header.appendChild(document.createTextNode(GNATdoc.EntitiesCategory.label));
    page.appendChild(header);

    for (var idx = 0; idx < GNATdoc.EntitiesCategory.entities.length; idx++) {
        var item;
        var entity = GNATdoc.EntitiesCategory.entities[idx];

        if (character == '' || character != entity.label[0].toUpperCase()) {
            character = entity.label[0].toUpperCase();
            item = document.createElement('dt');
            item.appendChild(document.createTextNode(character));
            list.appendChild(item);
        }

        item = document.createElement('dd');
        var href = document.createElement('a');
        href.href = '../' + entity.docHref;
        href.appendChild(document.createTextNode(entity.label));
        item.appendChild(href);
        item.appendChild(document.createTextNode(' from '));

        href = document.createElement('a');
        href.href = '../' + entity.srcHref;
        href.appendChild(document.createTextNode(entity.declared));
        item.appendChild(href);
        list.appendChild(item);
    }

    page.appendChild(list);
}

/**
 * ???
 * @param {Object} page    ???.
 */

function buildInheritanceIndex(page) {
    function build(list, entities) {
        for (var index = 0; index < entities.length; index++) {
            var item = document.createElement('li');
            var href = document.createElement('a');
            href.href = entities[index].docHref;
            href.appendChild(document.createTextNode(entities[index].label));
            item.appendChild(href);

            if (entities[index].inherited !== undefined) {
                var sublist = document.createElement('ul');
                build(sublist, entities[index].inherited);
                item.appendChild(sublist);
            }
            list.appendChild(item);
        }
    }

    var list = document.createElement('ul');

    build(list, GNATdoc.InheritanceIndex);
    page.appendChild(list);
}

/**
 * ???
 */

function displaySource() {
    var pane = document.getElementById('body');
    var header = document.createElement('h1');
    header.appendChild(document.createTextNode(GNATdoc.SourceFile.label));
    pane.appendChild(header);
    buildText(pane, [GNATdoc.SourceFile]);
}

/**
 * ???
 */

function onDocumentationLoad() {
    buildDocumentationPage();

    // Scroll view to requested element.

    var url = document.URL;
    var index = url.indexOf('#');

    if (index >= 0) {
        var id = url.slice(index + 1, url.length);
        var element = document.getElementById(id);

        if (element) {
            element.scrollIntoView();
        }
    }
}

/**
 * Hides TOC and deselect all items of its menu.
 */

function hideTOC() {
    var items = document.getElementById('tocView').children;

    for (var index = 0; index < items.length; index++)
    {
        items[index].style.display = 'none';
    }

    items = document.getElementById('tocMenu').children[0].children;

    for (var index = 0; index < items.length; index++)
    {
        items[index].className = '';
    }
}

/**
 * ???
 */

function displayPackagesAndClasses() {
    hideTOC();
    document.getElementById('contentView').src = 'blank.html';
    document.getElementById('packagesAndClasses').style.display = 'block';
    document.getElementById('packagesAndClassesMenu').className = 'current';
}

/**
 * Displays list of entities' categories
 */

function displayEntities() {
    hideTOC();
    document.getElementById('contentView').src = 'blank.html';
    document.getElementById('entities').style.display = 'block';
    document.getElementById('entitiesMenu').className = 'current';
}

/**
 * Displays inheritance tree of tagged types and classes
 */

function displayInheritance() {
    hideTOC();
    document.getElementById('contentView').src = 'inheritance_index.html';
    document.getElementById('inheritanceMenu').className = 'current';
}

/**
 * Displays list of source files
 */

function displaySources() {
    hideTOC();
    document.getElementById('contentView').src = 'blank.html';
    document.getElementById('sources').style.display = 'block';
    document.getElementById('sourcesMenu').className = 'current';
}

/**
 * ???
 */

function onLoad() {
    var toc = document.getElementById('tocView');
    var menu = document.getElementById('tocMenu');

    /* Build generic project informtion pane */

    document.getElementById('projectName').appendChild(
        document.createTextNode(GNATdoc.Index.project));
    document.getElementById('documentationTimestamp').appendChild(
        document.createTextNode(GNATdoc.Index.timestamp));

    /* Build main menu */

    var ul = document.createElement('ul');
    var li = document.createElement('li');
    var a = document.createElement('a');
    a.appendChild(document.createTextNode('Packages and Classes'));
    a.href = 'javascript:displayPackagesAndClasses();';
    li.appendChild(a);
    li.id = 'packagesAndClassesMenu';
    ul.appendChild(li);

    li = document.createElement('li');
    a = document.createElement('a');
    a.appendChild(document.createTextNode('Entities Index'));
    a.href = 'javascript:displayEntities();';
    li.appendChild(a);
    li.id = 'entitiesMenu';
    ul.appendChild(li);

    li = document.createElement('li');
    a = document.createElement('a');
    a.appendChild(document.createTextNode('Inheritance Tree'));
    a.href = 'javascript:displayInheritance();';
    li.appendChild(a);
    li.id = 'inheritanceMenu';
    ul.appendChild(li);

    li = document.createElement('li');
    a = document.createElement('a');
    a.appendChild(document.createTextNode('Source Files'));
    a.href = 'javascript:displaySources();';
    li.appendChild(a);
    li.id = 'sourcesMenu';
    ul.appendChild(li);

    menu.appendChild(ul);

    /* Build page content */

    buildPackagesIndex(toc);
    buildEntitiesCategoriesIndex(toc);

    var header = document.createElement('h1');
    var href = document.createElement('a');
    href.href = 'inheritance_index.html';
    href.target = 'contentView';
    href.appendChild(document.createTextNode('Inheritance Tree'));
    header.appendChild(href);
    toc.appendChild(header);

    buildSourcesIndex(toc);

    /* Display list of packages and classes */

    displayPackagesAndClasses();
}

/**
 * ???
 */

function onSourceFileLoad() {
    displaySource();

    /* Scroll view to requested element. */

    var url = document.URL;
    var index = url.indexOf('#');

    if (index >= 0) {
        var id = url.slice(index + 1, url.length);
        var element = document.getElementById(id);

        if (element) {
            element.scrollIntoView();
            element.classList.add('target');
        }
    }
}

/**
 * ???
 */

function onInheritanceLoad() {
    var page = document.getElementById('body');

    buildInheritanceIndex(page);
}

/**
 * ???
 */

function onEntitiesCategoryLoad() {
    buildEntitiesCategoryPage();
}
