# This file is part of 1clickBOM.
#
# 1clickBOM is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License version 3
# as published by the Free Software Foundation.
#
# 1clickBOM is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with 1clickBOM.  If not, see <http://www.gnu.org/licenses/>.

class @Digikey extends RetailerInterface
    constructor: (country_code, settings) ->
        super "Digikey", country_code, "/data/digikey_international.json", settings
        @icon_src = chrome.extension.getURL("images/digikey.ico")

    clearCart: ->
        that = this
        xhr = new XMLHttpRequest
        xhr.open("GET","http" + @site + @cart + "?webid=-1", true)
        xhr.onreadystatechange = () ->
            if xhr.readyState == 4
                that.refreshCartTabs()
        xhr.send()

    addItems: (items, callback) ->
        that = this
        request = {success:true, fails:[]}
        count = items.length
        for item in items
            xhr = new XMLHttpRequest
            xhr.open("POST", "http" + @site + @additem + "?qty=" + item.quantity + "&part=" + item.part + "&cref=" + item.comment, true)
            xhr.item = item
            xhr.onreadystatechange = (event) ->
                if event.currentTarget.readyState == 4
                    doc = (new DOMParser).parseFromString(event.currentTarget.responseText, "text/html")
                    #if the cart returns with a quick-add quantity filled-in there was an error
                    quick_add_quant = doc.querySelector("#ctl00_ctl00_mainContentPlaceHolder_mainContentPlaceHolder_txtQuantity")
                    success = (quick_add_quant?) && (quick_add_quant.value?) && (quick_add_quant.value == "")
                    if not success
                        request.fails.push(event.currentTarget.item)
                    request.success = request.success && success
                    count--
                    if (count == 0)
                        if callback?
                            callback(request, that)
                        that.refreshCartTabs()
            xhr.send()

     #getCart: ->
     #   that = this
     #   parser = new DOMParser
     #   xhr = new XMLHttpRequest
     #   xhr.open "GET", "https" + @site + @cart, false
     #   xhr.send()
     #   if xhr.status == 200
     #       doc = parser.parseFromString(xhr.responseText, "text/html")
     #   #table = doc.getElementById("ctl00_ctl00_mainContentPlaceHolder_mainContentPlaceHolder_ordOrderDetails").getElementsByTagName("tbody")[0]#.getElementsById("valSubtotal")[0]
     #   subtotal = doc.getElementById("valSubtotal").innerText
     #   subtotal = subtotal.replace(/\s*/g, '')
     #   subtotal = subtotal.replace(/€/g, '')
     #   subtotal = subtotal.replace(/\,/, '.')
     #   subtotal = parseFloat(subtotal)

     #   shipping = doc.getElementById("valShipping").innerText
     #   shipping = shipping.replace(/\s*/g, '')
     #   shipping = shipping.replace(/€/g, '')
     #   shipping = shipping.replace(/\,/, '.')
     #   shipping = parseFloat(shipping)

     #   total = doc.getElementById("valTotal").innerText
     #   total = total.replace(/\s*/g, '')
     #   if total == "unknown"
     #       total = NaN
     #   else
     #       total = total.replace(/€/g, '')
     #       total = total.replace(/\,/, '.')
     #       total = parseFloat(total)

     #   #table = table.getElementByTagName("tbody")[0]
     #   return {"subtotal":subtotal, "shipping":shipping, "total": total}
