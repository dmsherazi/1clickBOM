# The contents of this file are subject to the Common Public Attribution
# License Version 1.0 (the “License”); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://1clickBOM.com/LICENSE. The License is based on the Mozilla Public
# License Version 1.1 but Sections 14 and 15 have been added to cover use of
# software over a computer network and provide for limited attribution for the
# Original Developer. In addition, Exhibit A has been modified to be consistent
# with Exhibit B.
#
# Software distributed under the License is distributed on an
# "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations under
# the License.
#
# The Original Code is 1clickBOM.
#
# The Original Developer is the Initial Developer. The Original Developer of
# the Original Code is Kaspar Emanuel.

{RetailerInterface}   = require './retailer_interface'
{browser} = require './browser'
http = require './http'
post = http.post
get  = http.get

class Newark extends RetailerInterface
    constructor: (country_code, settings,callback) ->
        super('Newark', country_code, 'data/newark.json', settings)
        @_set_store_id () =>
            callback(this)

    clearCart: (callback) ->
        @clearing_cart = true
        @_get_item_ids (ids) =>
            @_clear_cart ids, (obj) =>
                @refreshCartTabs()
                @refreshSiteTabs()
                @clearing_cart = false
                if callback?
                    callback(obj)

    _set_store_id: (callback) ->
        url = 'https' + @site + @cart
        get url, {}, (event) =>
            doc = browser.parseDOM(event.target.responseText)
            id_elem = doc.getElementById('storeId')
            if id_elem?
                @store_id = id_elem.value
                callback()
        , () ->
            callback()


    _clear_cart: (ids, callback) ->
        url = "https#{@site}/webapp/wcs/stores/servlet/ProcessBasket"
        params = "langId=-1&orderId=&catalogId=15003&BASE_URL=BasketPage\
        &errorViewName=AjaxOrderItemDisplayView&storeId=#{@store_id}\
        &URL=BasketDataAjaxResponse&isEmpty=false&LoginTimeout=&LoginTimeoutURL=\
        &blankLinesResponse=10&orderItemDeleteAll="
        for id in ids
            params += '&orderItemDelete=' + id
        post url, params, {}, (event) =>
            callback({success:true}, this)
        , () =>
            #we actually successfully clear the cart on 404s
            callback({success:true}, this)

    _get_item_ids: (callback) ->
        url = 'https' + @site + @cart
        get url, {}, (event) =>
            doc = browser.parseDOM(event.target.responseText)
            order_details = doc.querySelector('#order_details')
            if order_details?
                tbody = order_details.querySelector('tbody')
                inputs = tbody.querySelectorAll('input')
            else
                inputs = []
            ids = []
            for input in inputs
                if input.type == 'hidden' && /orderItem_/.test(input.id)
                    ids.push(input.value)
            callback(ids)

    addItems: (items, callback) ->
        @adding_items = true
        @_add_items  items, (result) =>
            @refreshCartTabs()
            @refreshSiteTabs()
            @adding_items = false
            callback(result, this, items)

    _add_items: (items, callback) ->
        url = 'https' + @site + '/AjaxPasteOrderChangeServiceItemAdd'
        get url, {notify:false}, () =>
            @_add_items_ajax(items, callback)
        , () =>
            @_add_items_non_ajax(items, callback)

    _add_items_non_ajax: (items, callback) ->
        if items.length == 0
            if callback?
                callback({success:true, fails:[]})
            return
        url = 'https' + @site + '/webapp/wcs/stores/servlet/PasteOrderChangeServiceItemAdd'
        params = 'storeId=' + @store_id + '&catalogId=&langId=-1&omItemAdd=quickPaste&URL=AjaxOrderItemDisplayView%3FstoreId%3D10194%26catalogId%3D15003%26langId%3D-1%26quickPaste%3D*&errorViewName=QuickOrderView&calculationUsage=-1%2C-2%2C-3%2C-4%2C-5%2C-6%2C-7&isQuickPaste=true&quickPaste='
        #&addToBasket=Add+to+Cart'
        for item in items
            params += encodeURIComponent(item.part) + ','
            params += encodeURIComponent(item.quantity) + ','
            params += encodeURIComponent(item.comment) + '\n'
        post url, params, {}, (event) =>
            doc = browser.parseDOM(event.target.responseText)
            form_errors = doc.querySelector('#formErrors')
            success = true
            if form_errors?
                success = form_errors.className != ''
            if not success
                #we find out which parts are the problem, call addItems again
                #on the rest and concatenate the fails to the new result
                #returning everything together to our callback
                fail_names  = []
                fails       = []
                retry_items = []
                for item in items
                        regex = new RegExp item.part, 'g'
                        result = regex.exec(form_errors.innerHTML)
                        if result != null
                            fail_names.push(result[0])
                for item in items
                    if item.part in fail_names
                        fails.push(item)
                    else
                        retry_items.push(item)
                @_add_items_non_ajax retry_items, (result) ->
                    if callback?
                        result.fails = result.fails.concat(fails)
                        result.success = false
                        callback(result)
            else #success
                if callback?
                    callback({success: true, fails:[]})
        , () =>
            if callback?
                callback({success:false,fails:items})


    _add_items_ajax: (items, callback) ->
        result = {success: true, fails:[], warnings:[]}
        if items.length == 0
            if callback?
                callback({success:true, fails:[]})
            return
        url = 'https' + @site + '/AjaxPasteOrderChangeServiceItemAdd'

        params = 'storeId=' + @store_id + '&catalogId=&langId=-1&omItemAdd=quickPaste&URL=AjaxOrderItemDisplayView%3FstoreId%3D10194%26catalogId%3D15003%26langId%3D-1%26quickPaste%3D*&errorViewName=QuickOrderView&calculationUsage=-1%2C-2%2C-3%2C-4%2C-5%2C-6%2C-7&isQuickPaste=true&quickPaste='
        for item in items
            params += encodeURIComponent(item.part) + ','
            params += encodeURIComponent(item.quantity) + ','
            if item.comment.length > 30
                result.warnings.push("Truncated line-note when adding
                    #{@name} item to cart: #{item.comment}")
            params += encodeURIComponent(item.comment.substr(0,30)) + '\n'
        post url, params, {}, (event) =>
            stxt = event.target.responseText.split('\n')
            stxt2 = stxt[3 .. (stxt.length - 4)]
            stxt3 = ''
            for s in stxt2
                stxt3 += s
            json = JSON.parse(stxt3)
            if json.hasPartNumberErrors? or json.hasCommentErrors?
                #we find out which parts are the problem, call addItems again
                #on the rest and concatenate the fails to the new result
                #returning everything together to our callback
                fail_names  = []
                fails       = []
                retry_items = []
                for k,v of json
                    #the rest of the json items are the part numbers
                    if k != 'hasPartNumberErrors' and k != 'hasCommentErrors'
                        fail_names.push(v[0])
                for item in items
                    if item.part in fail_names
                        fails.push(item)
                    else
                        retry_items.push(item)
                @_add_items_ajax retry_items, (result) ->
                    if callback?
                        result.fails = result.fails.concat(fails)
                        result.success = false
                        callback(result)
            else #success
                if callback?
                    callback(result)
        , () =>
            if callback?
                callback({success:false,fails:items,warnings:result.warnings})

exports.Newark = Newark
