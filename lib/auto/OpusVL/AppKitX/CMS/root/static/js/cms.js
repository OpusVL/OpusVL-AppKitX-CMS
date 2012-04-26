$(function() {
    jQuery.fn.extend({
        insertAtCaret: function(valueToInsertAtCaret){
            return this.each( function(i) {
                if ( document.selection ) {
                    this.focus();
                    selection = document.selection.createRange();
                    selection.text = valueToInsertAtCaret;
                    this.focus();
                } else if ( this.selectionStart || this.selectionStart == "0" ) {
                    var startPosition = this.selectionStart;
                    var endPosition = this.selectionEnd;
                    var scrollTop = this.scrollTop;
                    this.value = this.value.substring(0, startPosition) + valueToInsertAtCaret + this.value.substring(endPosition, this.value.length);
                    this.focus();
                    this.selectionStart = startPosition + valueToInsertAtCaret.length;
                    this.selectionEnd = startPosition + valueToInsertAtCaret.length;
                    this.scrollTop = scrollTop;
                } else {
                    this.value += valueToInsertAtCaret;
                    this.focus();
                }
            })
        }
    });

    function insertToNic(str) {
        alert('Called');
        //$('textarea#nic').insertAtCaret(str);
        return true;
    }

    function insertAtCursor(editor, value){
        var editor = nicEditors.findEditor(editor);
        var range = editor.getRng();      
        
        console.log(range);
        console.log(range.endOffset);
        var editorField = editor.elm;
        var field_txt = $(editorField).html();
        console.log(field_txt);
        console.log($(editorField).text());
        $(editorField).html(field_txt.substring(0, range.startOffset) +
                                value +
                                field_txt.substring(range.endOffset, field_txt.length));
 
    }

    $('#add-element').click(function() {
        $('#ajax-slide').slideToggle();
        $.get(
            '/modules/cms/ajax/list_elements',
            function(data) {
                $('#ajax-slide').html(data);
            }
        );
    });

    // enable nicEdit on all textareas
    var nicInstance;
   // nicEditors.allTextAreas();
    nicInstance = new nicEditor({fullPanel : true}).panelInstance('nic',{hasPanel : true});
    $('#toggle-nic').click(function() {
        if (!nicInstance) {
            nicInstance = new nicEditor({fullPanel : true}).panelInstance('nic',{hasPanel : true});
        }
        else {
           nicInstance.removeInstance('nic');
           nicInstance = null;
        }
    });

    $('.insert-nic').live('click', function() {
        var editor = nicEditors.findEditor('nic');
        console.log(editor);
        var range = editor.getRng();
        editor = $(editor.elm);
        //$(editor).html(editor.html().substring(0, range.startOffset) + 'Moose' + editor.html().substring(range.endOffset, editor.html().length));
        insertAtCursor('nic', 'Moose');
        /*(console.log($(editor.e));
        $(editor.e).insertAtCaret('aaaa');
        $(editor.elm).html($(editor.e).val());*/
    });


    // form error message begone!
    $('.form_error_message').click(function() { $(this).fadeOut(300); });

});
