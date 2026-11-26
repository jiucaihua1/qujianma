package com.qujianma.qujianma

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class NativeParsedPickup(
    val code: String,
    val stationName: String,
    val source: String,
    val trackingNumber: String = "",
    val itemNote: String = "",
    val rawText: String = "",
)

private data class NativeStationRule(
    val standardName: String,
    val keywords: List<String>,
    val order: Int,
)

object PickupParserNative {
    private val keywordTriggerRegex = Regex(
        """(?:取件码|提货码|取货码|开柜码|开箱码|自提码|核销码|取件密码|取货密码|开柜密码|取件编号|取货编号|提货编号|取件号|取货号|货架号|货架码|凭码|请用|请凭|驿站|快递柜|智能柜|自提柜|丰巢|菜鸟|兔喜|妈妈驿站|多多驿站|多多买菜|速递易|近邻宝|蜜罐|代收点|自提点|京东派|京东自提|递管家|小邮局|熊猫快收|快宝|蓝店|百世邻里|极兔邻里|人工货架|取包裹|包裹已到|包裹已存|快件已到|快递已到|已放入|已存入|已入柜|已入站|请及时取件)"""
    )

    private val nonPickupNoiseRegex = Regex(
        """(?:验证码|动态码|校验码|登录码|支付密码|银行卡|信用卡|余额|消费|还款|账单|话费|流量|航班|列车|车票|电影票|登机口)"""
    )

    private val strongExpressAnchorRegex = Regex(
        """(?:取件码|提货码|取货码|开柜码|开箱码|自提码|驿站|快递柜|智能柜|丰巢|菜鸟|兔喜|多多驿站|速递易|近邻宝|京东派|递管家|小邮局|熊猫快收|快宝|包裹|快件|取件)"""
    )

    private val alreadyPickedUpRegex = Regex(
        """(?:已签收|已取出|已取走|已完成取件|已出库|签收成功)"""
    )

    private val explicitCodeRegex = Regex(
        """(?:取件码|提货码|取货码|开柜码|开箱码|自提码|核销码|取件密码|取货密码|开柜密码|取件编号|取货编号|提货编号|取件号|取货号|货架号|货架码|凭码|请凭|请用|凭|输入)\s*(?:[（(][^）)\n]{1,12}[）)])?\s*[为是:：]?\s*[“"【\[]?(?<!\*)([A-Za-z]{1,2}-\d{1,5}(?:-\d{1,5})?|[A-Za-z]?\d{1,3}(?:-\d{1,5}){1,3}[A-Z]?|[A-Za-z]\d{1,2}[A-Za-z]\d{1,4}|\d{1,3}[A-Za-z]\d{2,5}|[A-Za-z]\d{3,7}|\d{3,4}[ \t]\d{3,4}|\d{4,8})[”"】\]]?"""
    )

    private val codeBeforeKeywordRegex = Regex(
        """(?:(?:^|\n)\s*([A-Za-z]{1,2}-\d{1,5}(?:-\d{1,5})?|[A-Za-z]?\d{1,3}(?:-\d{1,5}){1,3}[A-Z]?|[A-Za-z]\d{1,2}[A-Za-z]\d{1,4}|\d{1,3}[A-Za-z]\d{2,5}|\d{3,4}[ \t]\d{3,4}|\d{4,8})\s*(?:\n|[ \t]+)\s*(?:取件码|提货码|取货码|开柜码|开箱码|自提码|取件密码)|(?<![A-Za-z0-9-:*])([A-Za-z]{1,2}-\d{1,5}(?:-\d{1,5})?|[A-Za-z]?\d{1,3}(?:-\d{1,5}){1,3}[A-Z]?|\d{1,3}[A-Za-z]\d{2,5}|\d{4,8})\s*(?:为您的|是您的|为|是)\s*(?:取件码|提货码|取货码|开柜码|开箱码|自提码))"""
    )

    private val multiCodeRegex = Regex(
        """(?:取件码|提货码|取货码|开柜码|自提码|货架号|请凭|请用|凭)\s*[为是:：]?\s*([A-Za-z0-9-]+(?:[、,，/]\s*[A-Za-z0-9-]+)+)"""
    )

    private val shelfCodeRegex = Regex(
        """(?<![A-Za-z0-9-:*])([A-Za-z]{1,2}-\d{1,5}(?:-\d{1,5})?|[A-Za-z]?\d{1,3}-\d{1,5}(?:-\d{1,5}){0,2}[A-Z]?)(?![A-Za-z0-9-:])"""
    )

    private val explicitTrackingRegex = Regex(
        """(?:运单号|快递单号|单号)\s*[:：]?\s*([A-Za-z]{0,4}\d{10,16})"""
    )

    private val carrierTrackingRegex = Regex(
        """\b((?:SF|YT|JT|ZT|YD|JDVA|JDV|JDX|JD|ST|EMS|EA|EB|DPK)[A-Za-z0-9]{9,15}|(?:43|46|75|77|78|98)\d{11,13})\b""",
        RegexOption.IGNORE_CASE
    )

    private val bracketBrandRegex = Regex(
        """[【\[]([^【\[\]】]{2,16}(?:菜鸟|驿站|丰巢|兔喜|多多|妈妈|速递易|近邻宝|蜜罐|快递|代收|顺丰|中通|圆通|申通|韵达|极兔|京东|递管家|小邮局|熊猫快收|快宝|蓝店|百世邻里)[^【\[\]】]{0,8})[】\]]"""
    )

    private val smsHeaderSplitRegex = Regex(
        """(?=[【\[][^【\[\]】]{0,12}(?:菜鸟|驿站|丰巢|兔喜|多多|妈妈|速递易|近邻宝|蜜罐|快递|代收|顺丰|中通|圆通|申通|韵达|极兔|京东|递管家|小邮局|熊猫快收|快宝|蓝店|百世邻里)[^【\[\]】]{0,8}[】\]])"""
    )

    private val stationLocationRegex = Regex(
        """(?:已到|到达|已存放在?|已存入|已放入|已放至|已抵达|已入柜|送达|存放在?|存入|到|至)\s*([^\s，。！？,.;；:：【】\[\]]{2,38}?(?:菜鸟校园驿站|菜鸟驿站|圆通妈妈驿站|妈妈驿站|兔喜生活|兔喜快递超市|兔喜驿站|多多驿站|多多买菜自提点|丰巢快递柜|丰巢智能柜|丰巢柜|丰巢|中邮速递易|速递易|近邻宝智能柜|近邻宝快递柜|近邻宝|蜜罐|京东派|京东快递柜|京东自提柜|京东自提点|校园派|校园小邮局|小邮局|熊猫快收|快宝驿站|蓝店|百世邻里|极兔邻里|顺丰服务点|顺丰驿站|公共服务站|便民服务站|快递服务中心|物流服务中心|快递超市|驿站超市|快递柜|智能柜|自提柜|快递站|快递点|服务站|服务点|驿站|代收点|自提点|收发室|收发点|门卫))"""
    )

    private val genericStationRegex = Regex(
        """([^\s，。！？,.;；:：【】\[\]]{0,30}(?:菜鸟校园驿站|菜鸟驿站|圆通妈妈驿站|妈妈驿站|兔喜生活|兔喜快递超市|兔喜驿站|多多驿站|多多买菜自提点|丰巢快递柜|丰巢智能柜|丰巢柜|丰巢|中邮速递易|速递易|近邻宝智能柜|近邻宝快递柜|近邻宝|蜜罐|京东派|京东快递柜|京东自提柜|京东自提点|校园派|校园小邮局|小邮局|熊猫快收|快宝驿站|蓝店|百世邻里|极兔邻里|顺丰服务点|顺丰驿站|公共服务站|便民服务站|快递服务中心|物流服务中心|快递超市|驿站超市|快递柜|智能柜|自提柜|快递站|快递点|服务站|服务点|驿站|代收点|自提点))"""
    )

    private val listStationHeaderRegex = Regex(
        """^(?:代收点|自提点|快递柜|驿站|多多买菜|菜鸟乡村|菜鸟驿站|菜鸟直送|兔喜生活|妈妈驿站|丰巢)\s+(.{2,48})$"""
    )

    private val listStationTagOnlyRegex = Regex(
        """^(?:代收点|自提点|快递柜|驿站|多多买菜|菜鸟乡村|菜鸟驿站|菜鸟直送|兔喜生活|妈妈驿站|丰巢)$"""
    )

    private val standaloneStationHeaderRegex = Regex(
        """(?:菜鸟驿站|妈妈驿站|兔喜生活|多多驿站|丰巢快递柜|丰巢智能柜|公共服务站|便民服务站|驿站超市|驿站|快递柜|代收点)$"""
    )

    private val listItemLineRegex = Regex(
        """^(?:天猫|淘宝|拼多多|京东|抖音|快手)\s*[|｜]\s*(?:[【\[][^】\]]+[】\]]的?)?\s*(.{2,100})$"""
    )

    private val itemNoteRegex = Regex(
        """(?:商品|物品|包裹内容|宝贝)\s*[:：]\s*([^\n，。]{2,24})"""
    )

    private val hyphenVariantRegex = Regex("""[—–－]""")
    private val spacedHyphenRegex = Regex("""(?<=[A-Za-z0-9])\s*-\s*(?=[A-Za-z0-9])""")
    private val validCodeRegex = Regex("""^[A-Z0-9-]+$""")
    private val mobilePlainRegex = Regex("""^1[3-9]\d{9}$""")
    private val yearOnlyRegex = Regex("""^20\d{2}$""")
    private val yyyyMmDdRegex = Regex("""^20\d{2}-\d{1,2}(?:-\d{1,2})?$""")
    private val landlineOrHotlineRegex = Regex("""^(?:400|800|0\d{2,3})-""")
    private val mobileHyphenRegex = Regex("""^1[3-9]\d-\d{4}-\d{4}$""")
    private val mmDdRegex = Regex("""^(\d{1,2})-(\d{1,2})$""")
    private val timeSuffixRegex = Regex("""^\s+\d{1,2}:\d{2}""")
    private val nonPickupPrefixRegex = Regex(
        """(?:日期|时间|体重|建议|身高|尺码|码数|适合|适用|约重|净重|毛重|重量|规格|尺寸|鞋码|腰围|胸围|臀围|衣长|裤长|肩宽|袖长|温度|满减|优惠|折扣|区间|范围|年龄|(?:[XSML]|XL|XXL|XXXL|2XL|3XL|4XL|5XL)\s*[（(]?)$""",
        RegexOption.IGNORE_CASE
    )
    private val nonPickupUnitSuffixRegex = Regex(
        """^\s*(?:斤|公斤|kg|g|mg|cm|mm|dm|m|ml|l|码|岁|元|块|折|天|小时|时|分钟|分|秒|件|个|双|人|度|℃|%|％|万|千|百)(?![A-Za-z0-9])""",
        RegexOption.IGNORE_CASE
    )

    @Volatile
    private var cachedBundleRaw: String? = null

    @Volatile
    private var activeStationLocationRegex: Regex = stationLocationRegex

    @Volatile
    private var activeGenericStationRegex: Regex = genericStationRegex

    @Volatile
    private var activeListHeaderRegex: Regex = listStationHeaderRegex

    @Volatile
    private var activeListTagOnlyRegex: Regex = listStationTagOnlyRegex

    @Volatile
    private var activeStandaloneHeaderRegex: Regex = standaloneStationHeaderRegex

    @Volatile
    private var cachedPresetRules: List<NativeStationRule> = emptyList()

    private fun refreshDynamicBundleIfNeeded(context: Context?) {
        if (context == null) return
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.parser_rules_bundle_v1", null)
            if (raw == cachedBundleRaw) return

            if (raw.isNullOrBlank()) {
                cachedBundleRaw = raw
                activeStationLocationRegex = stationLocationRegex
                activeGenericStationRegex = genericStationRegex
                activeListHeaderRegex = listStationHeaderRegex
                activeListTagOnlyRegex = listStationTagOnlyRegex
                activeStandaloneHeaderRegex = standaloneStationHeaderRegex
                cachedPresetRules = emptyList()
                return
            }

            val obj = JSONObject(raw)
            fun readEscapedAlternation(key: String): String {
                val arr = obj.optJSONArray(key) ?: return ""
                val items = mutableListOf<String>()
                for (i in 0 until arr.length()) {
                    val s = arr.optString(i, "").trim()
                    if (s.isNotEmpty()) items.add(Regex.escape(s))
                }
                return items.distinct().sortedByDescending { it.length }.joinToString("|")
            }

            val prefixAlt = readEscapedAlternation("listStationPrefixes")
            if (prefixAlt.isNotEmpty()) {
                activeListHeaderRegex = Regex("""^(?:$prefixAlt)\s+(.{2,48})$""")
                activeListTagOnlyRegex = Regex("""^(?:$prefixAlt)$""")
            }

            val suffixAlt = readEscapedAlternation("stationSuffixes")
            if (suffixAlt.isNotEmpty()) {
                activeStationLocationRegex = Regex(
                    """(?:已到|到达|已存放在?|已存入|已放入|已放至|已抵达|已入柜|送达|存放在?|存入|到|至)\s*([^\s，。！？,.;；:：【】\[\]]{2,38}?(?:$suffixAlt|收发室|收发点|门卫))"""
                )
                activeGenericStationRegex = Regex(
                    """([^\s，。！？,.;；:：【】\[\]]{0,30}(?:$suffixAlt))"""
                )
                activeStandaloneHeaderRegex = Regex("""(?:$suffixAlt)$""")
            }

            val presetsArr = obj.optJSONArray("presetStationRules")
            val presets = mutableListOf<NativeStationRule>()
            if (presetsArr != null) {
                for (i in 0 until presetsArr.length()) {
                    val rObj = presetsArr.optJSONObject(i) ?: continue
                    if (!rObj.optBoolean("enabled", true)) continue
                    val stdName = rObj.optString("standardName", "").trim()
                    if (stdName.isEmpty()) continue
                    val kws = mutableListOf(stdName)
                    val aArr = rObj.optJSONArray("aliases")
                    if (aArr != null) {
                        for (j in 0 until aArr.length()) {
                            val a = aArr.optString(j, "").trim()
                            if (a.isNotEmpty() && !kws.contains(a)) kws.add(a)
                        }
                    }
                    presets.add(NativeStationRule(stdName, kws, rObj.optInt("order", i)))
                }
            }
            cachedPresetRules = presets.sortedBy { it.order }
            cachedBundleRaw = raw
        } catch (_: Throwable) {
            // Keep existing compiled regexes on malformed JSON
        }
    }

    fun looksLikePickupSms(rawText: String): Boolean {
        val text = rawText.trim()
        if (text.length < 8 || text.length > 1200) return false
        if (nonPickupNoiseRegex.containsMatchIn(text) && !strongExpressAnchorRegex.containsMatchIn(text)) {
            return false
        }
        if (alreadyPickedUpRegex.containsMatchIn(text) &&
            !Regex("""(?:取件码|提货码|取货码|开柜码|请凭|请用|待取)""").containsMatchIn(text)
        ) {
            return false
        }
        return keywordTriggerRegex.containsMatchIn(text)
    }

    fun parseAll(
        rawText: String,
        defaultSource: String = "ocr",
        context: Context? = null,
    ): List<NativeParsedPickup> {
        val text = rawText.trim()
        if (text.isEmpty()) return emptyList()

        refreshDynamicBundleIfNeeded(context)
        val rules = if (context != null) loadStationRules(context) else emptyList()
        val presetRules = cachedPresetRules

        val listParsed = parseStationListLayout(text, defaultSource)
        if (listParsed.isNotEmpty()) return applyStationRules(listParsed, rules, presetRules)

        val blocks = splitIntoBlocks(text)
        val results = mutableListOf<NativeParsedPickup>()
        val seenKeys = mutableSetOf<String>()

        for (block in blocks) {
            val parsed = parseBlock(block, defaultSource)
            for (item in parsed) {
                val dedupKey = "${item.stationName}|${item.code}"
                if (seenKeys.add(dedupKey)) {
                    results.add(item)
                }
            }
        }
        return applyStationRules(results, rules, presetRules)
    }

    private fun loadStationRules(context: Context): List<NativeStationRule> {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.station_rules_v1", null) ?: return emptyList()
            if (raw.isBlank()) return emptyList()
            val arr = JSONArray(raw)
            val rules = mutableListOf<NativeStationRule>()
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                if (!obj.optBoolean("enabled", true)) continue
                val standardName = obj.optString("standardName", "").trim()
                if (standardName.isEmpty()) continue
                val keywords = mutableListOf(standardName)
                val aliasesArr = obj.optJSONArray("aliases")
                if (aliasesArr != null) {
                    for (j in 0 until aliasesArr.length()) {
                        val alias = aliasesArr.optString(j, "").trim()
                        if (alias.isNotEmpty() && !keywords.contains(alias)) {
                            keywords.add(alias)
                        }
                    }
                }
                rules.add(
                    NativeStationRule(
                        standardName = standardName,
                        keywords = keywords,
                        order = obj.optInt("order", i),
                    )
                )
            }
            rules.sortedBy { it.order }
        } catch (_: Throwable) {
            emptyList()
        }
    }

    private val matchNormalizeRegex = Regex("""[\s\-_·•/\\,，。.;；:：!！?？()（）【】\[\]]""")

    private fun normalizeForMatch(input: String): String {
        return matchNormalizeRegex.replace(input, "").lowercase()
    }

    private fun matchRuleList(haystack: String, rules: List<NativeStationRule>): String? {
        var bestStandard: String? = null
        var bestLen = 0
        for (rule in rules) {
            for (kw in rule.keywords) {
                val normKw = normalizeForMatch(kw)
                if (normKw.isNotEmpty() && haystack.contains(normKw) && normKw.length > bestLen) {
                    bestLen = normKw.length
                    bestStandard = rule.standardName
                }
            }
        }
        return bestStandard
    }

    private fun applyStationRules(
        items: List<NativeParsedPickup>,
        rules: List<NativeStationRule>,
        presetRules: List<NativeStationRule> = emptyList(),
    ): List<NativeParsedPickup> {
        if ((rules.isEmpty() && presetRules.isEmpty()) || items.isEmpty()) return items
        return items.map { item ->
            val haystack = normalizeForMatch("${item.rawText.trim()}\n${item.stationName.trim()}")
            if (haystack.isEmpty()) return@map item
            val bestStandard = matchRuleList(haystack, rules) ?: matchRuleList(haystack, presetRules)
            if (bestStandard != null && bestStandard != item.stationName) {
                item.copy(stationName = bestStandard)
            } else {
                item
            }
        }
    }

    private fun parseStationListLayout(
        text: String,
        defaultSource: String,
    ): List<NativeParsedPickup> {
        val rawLines = text
            .split(Regex("""\r?\n"""))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (rawLines.size < 3) return emptyList()

        // Merge split 2-line station headers (e.g. "代收点\n沈理东门驿站超市")
        val lines = mutableListOf<String>()
        var idx = 0
        while (idx < rawLines.size) {
            val cur = rawLines[idx]
            if (activeListTagOnlyRegex.matches(cur) && idx + 1 < rawLines.size) {
                val next = rawLines[idx + 1]
                if (next.length in 2..48 && extractCodes(next).isEmpty()) {
                    lines.add("$cur $next")
                    idx += 2
                    continue
                }
            }
            lines.add(cur)
            idx++
        }

        val hasHeader = lines.any { extractListHeaderStation(it) != null }
        if (!hasHeader) return emptyList()

        val results = mutableListOf<NativeParsedPickup>()
        val seenCodes = mutableSetOf<String>()
        var currentStation = "默认驿站"
        var currentHeaderLine = ""
        var currentSource = defaultSource

        for (i in lines.indices) {
            val line = lines[i]
            if (line.startsWith("近日签收") || line.startsWith("全部包裹")) {
                break
            }

            val headerStation = extractListHeaderStation(line)
            if (headerStation != null) {
                currentStation = headerStation
                currentHeaderLine = line
                currentSource = detectSource(line, defaultSource)
                continue
            }

            if (listItemLineRegex.matches(line)) continue

            val codes = extractCodes(line)
            if (codes.isEmpty()) continue

            var note = ""
            var source = currentSource
            var tracking = ""
            for (j in (i + 1)..(i + 2).coerceAtMost(lines.lastIndex)) {
                val nextLine = lines[j]
                if (extractListHeaderStation(nextLine) != null) break
                if (extractCodes(nextLine).isNotEmpty()) break
                val itemMatch = listItemLineRegex.matchEntire(nextLine)
                if (itemMatch != null && note.isEmpty()) {
                    val rawNote = itemMatch.groupValues[1].trim()
                    note = if (rawNote.length > 22) rawNote.take(22) else rawNote
                    source = detectSource(nextLine, source)
                }
                if (tracking.isEmpty()) {
                    tracking = extractTrackingNumber(nextLine)
                }
            }

            for (code in codes) {
                if (seenCodes.add(code)) {
                    results.add(
                        NativeParsedPickup(
                            code = code,
                            stationName = currentStation,
                            source = source,
                            trackingNumber = tracking,
                            itemNote = note,
                            rawText = if (currentHeaderLine.isEmpty()) line else "$currentHeaderLine\n$line",
                        )
                    )
                }
            }
        }
        return results
    }

    private fun extractListHeaderStation(rawLine: String): String? {
        val line = rawLine.replace(Regex("""[>›»]+$"""), "").trim()
        if (line.length < 3 || line.length > 56) return null
        if (extractCodes(line).isNotEmpty()) return null

        activeListHeaderRegex.matchEntire(line)?.let { match ->
            val cleaned = cleanStationName(match.groupValues[1])
            if (cleaned.length >= 2) return cleaned
        }

        if (!line.contains("。") &&
            !line.contains("您的") &&
            !line.contains("包裹") &&
            !line.contains("凭") &&
            activeStandaloneHeaderRegex.containsMatchIn(line)
        ) {
            val cleaned = cleanStationName(line)
            if (cleaned.length >= 2) return cleaned
        }
        return null
    }

    private fun splitIntoBlocks(text: String): List<String> {
        val byBlankLine = text
            .split(Regex("""\r?\n\s*\r?\n"""))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (byBlankLine.size > 1) return byBlankLine

        val headerStarts = smsHeaderSplitRegex
            .findAll(text)
            .map { it.range.first }
            .toList()
        if (headerStarts.size > 1) {
            val segments = mutableListOf<String>()
            for (i in headerStarts.indices) {
                val start = headerStarts[i]
                val end = if (i + 1 < headerStarts.size) headerStarts[i + 1] else text.length
                val seg = text.substring(start, end).trim()
                if (seg.isNotEmpty()) segments.add(seg)
            }
            if (segments.size > 1) return segments
        }

        return listOf(text)
    }

    private fun parseBlock(block: String, defaultSource: String): List<NativeParsedPickup> {
        val station = extractStation(block)
        val allowBareShelfCodes = keywordTriggerRegex.containsMatchIn(block) || station != "默认驿站"
        val codes = extractCodes(block, allowBareShelfCodes = allowBareShelfCodes)
        if (codes.isEmpty()) return emptyList()

        val source = detectSource(block, defaultSource)
        val tracking = extractTrackingNumber(block)
        val note = extractItemNote(block)

        return codes.map { code ->
            NativeParsedPickup(
                code = code,
                stationName = station,
                source = source,
                trackingNumber = tracking,
                itemNote = note,
                rawText = block,
            )
        }
    }

    private fun extractCodes(
        rawText: String,
        allowBareShelfCodes: Boolean = true,
    ): List<String> {
        val text = spacedHyphenRegex.replace(
            hyphenVariantRegex.replace(rawText, "-"),
            "-"
        )
        val found = mutableListOf<String>()

        fun addCode(raw: String) {
            val normalized = hyphenVariantRegex.replace(raw, "-")
                .replace(Regex("""[ \t]+"""), "")
                .trim()
                .uppercase()
            if (isValidPickupCode(normalized) && !found.contains(normalized)) {
                found.add(normalized)
            }
        }

        for (m in explicitCodeRegex.findAll(text)) {
            m.groups[1]?.value?.let(::addCode)
        }

        for (m in codeBeforeKeywordRegex.findAll(text)) {
            (m.groups[1]?.value ?: m.groups[2]?.value)?.let(::addCode)
        }

        for (m in multiCodeRegex.findAll(text)) {
            val group = m.groups[1]?.value ?: continue
            for (part in group.split(Regex("""[、,，/\s]+"""))) {
                if (part.isNotEmpty()) addCode(part)
            }
        }

        if (allowBareShelfCodes) {
            for (m in shelfCodeRegex.findAll(text)) {
                val value = m.groups[1]?.value ?: continue
                if (!looksLikeDateOrPhone(value, text, m.range.first, m.range.last + 1)) {
                    addCode(value)
                }
            }
        }

        return found
    }

    private fun isValidPickupCode(code: String): Boolean {
        if (code.length < 3 || code.length > 16) return false
        if (mobilePlainRegex.matches(code)) return false
        if (yearOnlyRegex.matches(code)) return false
        return validCodeRegex.matches(code)
    }

    private fun looksLikeDateOrPhone(
        value: String,
        fullText: String,
        start: Int,
        end: Int,
    ): Boolean {
        if (yyyyMmDdRegex.matches(value)) return true
        if (landlineOrHotlineRegex.containsMatchIn(value)) return true
        if (mobileHyphenRegex.matches(value)) return true

        val mmdd = mmDdRegex.matchEntire(value)
        if (mmdd != null) {
            val m = mmdd.groupValues[1].toIntOrNull() ?: 0
            val d = mmdd.groupValues[2].toIntOrNull() ?: 0
            if (m in 1..12 && d in 1..31) {
                val suffixEnd = (end + 10).coerceAtMost(fullText.length)
                val suffix = fullText.substring(end.coerceAtMost(fullText.length), suffixEnd)
                if (timeSuffixRegex.containsMatchIn(suffix)) return true
                if (mmdd.groupValues[1].startsWith("0") || mmdd.groupValues[2].startsWith("0")) {
                    return true
                }
            }
        }

        val prefixStart = (start - 16).coerceAtLeast(0)
        val prefix = fullText.substring(prefixStart, start.coerceAtMost(fullText.length))
        if (nonPickupPrefixRegex.containsMatchIn(prefix)) return true

        val suffixEnd = (end + 8).coerceAtMost(fullText.length)
        val suffix = fullText.substring(end.coerceAtMost(fullText.length), suffixEnd)
        if (nonPickupUnitSuffixRegex.containsMatchIn(suffix)) return true
        return false
    }

    private fun extractStation(text: String): String {
        activeStationLocationRegex.find(text)?.groups?.get(1)?.value?.let {
            val candidate = cleanStationName(it)
            if (candidate.length >= 2) return candidate
        }

        activeGenericStationRegex.find(text)?.groups?.get(1)?.value?.let {
            val candidate = cleanStationName(it)
            if (candidate.length >= 2) return candidate
        }

        bracketBrandRegex.find(text)?.groups?.get(1)?.value?.trim()?.let {
            if (it.isNotEmpty()) return it
        }

        return when {
            text.contains("菜鸟") -> "菜鸟驿站"
            text.contains("丰巢") -> "丰巢快递柜"
            text.contains("兔喜") -> "兔喜生活"
            text.contains("妈妈驿站") -> "妈妈驿站"
            text.contains("多多") -> "多多驿站"
            else -> "默认驿站"
        }
    }

    private fun cleanStationName(raw: String): String {
        var name = raw.trim()
            .replaceFirst(Regex("""^(?:您的包裹|包裹|快递|快件|请到|请前往|前往|位于|在|地址[:：]?|取件地址[:：]?)"""), "")
            .replace(Regex("""[（(【\[][^）)】\]]{1,16}[）)】\]]"""), "")
            .replace(Regex("""[-—_:：,，。.\s…>›»]+$"""), "")
            .trim()

        val stationKw = Regex(
            """(?:菜鸟驿站|妈妈驿站|兔喜生活|兔喜快递超市|多多驿站|丰巢快递柜|丰巢智能柜|丰巢柜|丰巢|速递易|近邻宝|京东派|快递服务中心|驿站超市|快递超市|快递柜|快递站|快递点|小邮局|熊猫快收|快宝驿站|驿站|代收点)"""
        )

        if (name.contains('，') || name.contains(',')) {
            val parts = name.split(Regex("""[，,]+""")).map { it.trim() }.filter { it.isNotEmpty() }
            for (i in parts.indices.reversed()) {
                if (stationKw.containsMatchIn(parts[i]) && parts[i].length >= 3) {
                    name = parts[i]
                    break
                }
            }
        }

        val kwMatches = stationKw.findAll(name).toList()
        if (kwMatches.size >= 2) {
            val prevEnd = kwMatches[kwMatches.size - 2].range.last + 1
            val tail = name.substring(prevEnd)
                .replaceFirst(Regex("""^[-—_:：\s]+"""), "")
                .trim()
            val isGenericOnly = Regex("""^(?:代收点|门店|自提点|服务站|驿站|快递柜|驿站超市|快递超市)$""")
                .matches(tail)
            if (tail.length >= 4 && !isGenericOnly && stationKw.containsMatchIn(tail)) {
                name = tail
            }
        }

        name = name.replaceFirst(
            Regex("""^(?:[\u4e00-\u9fa5]{2,5}(?:省|自治区))?(?:[\u4e00-\u9fa5]{2,6}市)?(?:[\u4e00-\u9fa5]{2,6}(?:区|县|旗))?(?:[\u4e00-\u9fa5]{2,8}(?:街道|镇|乡))?"""),
            ""
        ).replace(Regex("""[-—_:：,，。.\s…>›»]+$"""), "").trim()

        if (name.length > 18) {
            name = name.takeLast(18)
        }
        return name.trim()
    }

    private fun detectSource(text: String, fallback: String): String {
        return when {
            text.contains("淘宝") || text.contains("天猫") || text.contains("菜鸟") -> "taobao"
            text.contains("拼多多") || text.contains("多多驿站") || text.contains("多多买菜") -> "pinduoduo"
            else -> fallback
        }
    }

    private fun extractTrackingNumber(text: String): String {
        explicitTrackingRegex.find(text)?.groups?.get(1)?.value?.let {
            return it.uppercase()
        }
        carrierTrackingRegex.find(text)?.groups?.get(1)?.value?.let {
            return it.uppercase()
        }
        return ""
    }

    private fun extractItemNote(text: String): String {
        return itemNoteRegex.find(text)?.groups?.get(1)?.value?.trim() ?: ""
    }
}
