/**
* addElement
* @description: Add element nicEdit plugin
* @requires: nicCore, nicPane, nicAdvancedButton
* @author: Brad Haywood
* @version: 0.0.1
*/
 
/* START CONFIG */
var nicElementOptions = {
    buttons : {
        'element' : {name : __('Add an element'), type : 'nicEditorAddElement'}
    }/* NICEDIT_REMOVE_START */,iconFiles : {'element' : '/static/js/src/addElement/icons/element.gif'}/* NICEDIT_REMOVE_END */
};
/* END CONFIG */
 
var nicEditorAddElement = nicEditorButton.extend({   
  mouseClick : function() {
       var e = $(document.createElement('div'));
       e.dialog({
            autoOpen : false,
            modal    : true,
            title    : 'Add Element',
            buttons  : {
                OK   : function() { $(this).dialog('close'); },
            },
       });
       $.get(
            '/modules/cms/ajax/add_element',
            function(data) {
                e.html(data);
            }
       );
       e.attr('id', 'element-box');
       e.dialog('open');
  }
});
 
nicEditors.registerPlugin(nicPlugin,nicElementOptions);
