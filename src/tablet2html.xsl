<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="#all" version="2.0">
    <xsl:param name="taxonomies.path"/>
    <xsl:param name="makeAnnotateLink" select="'true'"/>
    <xsl:variable name="taxonomies" select="doc($taxonomies.path)"/>
    <xsl:template match="/tei:TEI">
        <div id="html_{@xml:id}">
            <h3>
                <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title"/>
            </h3>
            <p>
                <a href="$tablets-root/{@xml:id}/{@xml:id}.xml">show XML source</a>
            </p>
            <table class="table">
                <xsl:apply-templates select="tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:msDesc"/>
                <xsl:apply-templates select="tei:teiHeader/tei:profileDesc"/>
            </table>
            <h4>Annotated Signs</h4>
            <div id="tabletHTMLContainer">
                <xsl:for-each select="//tei:g">
                    <xsl:sort select="@type"/>
                    <xsl:apply-templates select="."/>
                </xsl:for-each>
            </div>
        </div>
    </xsl:template>
    <xsl:template match="tei:msDesc">
        <tr>
            <td>
                <xsl:for-each select="tei:msIdentifier/*[self::tei:idno or self::tei:altIdentifier][normalize-space(.)!='']">
                    <xsl:choose>
                        <xsl:when test="self::tei:idno">
                            <xsl:text>Text reference</xsl:text>
                        </xsl:when>
                        <xsl:when test="self::tei:altIdentifier[@type='museumNumber']!=''">
                            <xsl:if test="parent::*/ancestor::tei:idno!=''">
                                <xsl:text> | </xsl:text>
                            </xsl:if>
                            <xsl:text>Museum no.</xsl:text>
                        </xsl:when>
                        <xsl:when test="self::altIdentifier[@type='CDLI']">
                            <xsl:if test="parent::*/ancestor::tei:altIdentifier[@type='museumNumber']!=''">
                                <xsl:text> | </xsl:text>
                            </xsl:if>
                            <xsl:text>CDLI no.</xsl:text>
                        </xsl:when>
                        <xsl:when test="self::tei:altIdentifier[@type='NABUCCO']">
                            <xsl:if test="parent::*/ancestor::tei:altIdentifier[@type='CDLI']!=''">
                                <xsl:text> | </xsl:text>
                            </xsl:if>
                            <xsl:text>NABUCCO no.</xsl:text>
                        </xsl:when>
                    </xsl:choose>
                    <xsl:text> | </xsl:text>
                </xsl:for-each>
            </td>
            <td>
                <xsl:for-each select="tei:msIdentifier/*[self::tei:idno or self::tei:altIdentifier][normalize-space(.)!='']">
                    <xsl:apply-templates select="."/>
                    <xsl:text> | </xsl:text>
                </xsl:for-each>
            </td>
        </tr>

        <xsl:if test="(tei:msIdentifier/*[self::tei:region or self::tei:collection])[.!='']">
            <tr>
                <td>Region | Archive | Dossier</td>
                <td>
                    <xsl:for-each select="(tei:msIdentifier/*[self::tei:region or self::tei:collection])">
                        <xsl:apply-templates select="."/>
                        <xsl:text> | </xsl:text>
                    </xsl:for-each>
                </td>
            </tr>
        </xsl:if>
        <xsl:if test="tei:physDesc/tei:handDesc/tei:handNote/tei:persName[.!='']">
            <tr>
                <td>Scribe</td>
                <td>
                    <xsl:value-of select="tei:physDesc/tei:handDesc/tei:handNote/tei:persName"/>
                </td>
            </tr>
        </xsl:if>
    </xsl:template>

    <xsl:template match="tei:msIdentifier/*">
        <xsl:choose>
            <xsl:when test="normalize-space(.) != ''">
                <xsl:value-of select="."/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> n/a </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>


    <xsl:template match="tei:profileDesc">
        <xsl:variable name="periodID" select="tei:creation/tei:origDate/tei:date/@period"/>
        <xsl:if test="(tei:creation/tei:origPlace/tei:placeName|$taxonomies//tei:catDesc[parent::tei:category/@xml:id = $periodID]|tei:creation/tei:origDate/tei:date[@calendar='#gregorian']|tei:creation/tei:origDate/tei:date[@calendar='#babylonian'])[.!='']">
            <tr>
                <td>
                    <xsl:if test="tei:creation/tei:origPlace/tei:placeName[.!='']">
                        <xsl:text>Place</xsl:text>
                    </xsl:if>
                    <xsl:if test="$periodID!=''">
                        <xsl:if test="tei:creation/tei:origPlace/tei:placeName[.!='']">
                            <xsl:text> | </xsl:text>
                        </xsl:if>
                        <xsl:text>Period</xsl:text>
                    </xsl:if>
                    <xsl:if test="tei:creation/tei:origDate/tei:date[@calendar='#gregorian']!=''">
                        <xsl:if test="$periodID!=''">
                            <xsl:text> | </xsl:text>
                        </xsl:if>
                        <xsl:text>Date</xsl:text>
                    </xsl:if>
                    <xsl:if test="tei:creation/tei:origDate/tei:date[@calendar='#babylonian']!=''">
                        <xsl:if test="tei:creation/tei:origDate/tei:date[@calendar='#gregorian']!=''">
                            <xsl:text> | </xsl:text>
                        </xsl:if>
                        <xsl:text>Date (Babylonian)</xsl:text>
                    </xsl:if>
                </td>
                <td>
                    <xsl:for-each select="(tei:creation/tei:origPlace/tei:placeName|$taxonomies//tei:catDesc[parent::tei:category/@xml:id = $periodID]|tei:creation/tei:origDate/tei:date[@calendar='#gregorian']|tei:creation/tei:origDate/tei:date[@calendar='#babylonian'])[.!='']">
                        <xsl:value-of select="(.,'n/a')[1]"/>
                        <xsl:text> | </xsl:text>
                    </xsl:for-each>
                </td>
            </tr>
        </xsl:if>
        <xsl:if test="tei:particDesc/*[.!='']">
            <tr>
                <td>Persons mentioned</td>
                <xsl:value-of select="string-join(tei:particDesc/*,', ')"/>
            </tr>
        </xsl:if>
        <xsl:if test="tei:textClass/tei:keywords/tei:term[.!='']">
            <tr>
                <td>Genre</td>
                <td>
                    <xsl:value-of select="string-join(tei:textClass/tei:keywords/tei:term,', ')"/>
                </td>
            </tr>
        </xsl:if>
        <xsl:if test="tei:abstract/tei:ab[.!='']">
            <tr>
                <td>Paraphrase</td>
                <td>
                    <xsl:value-of select="tei:abstract/tei:ab"/>
                </td>
            </tr>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tei:g">
        <xsl:variable name="annotation-id" select="substring-after(@xml:id, 'glyph_')"/>
        <xsl:variable name="tablet-id" select="root()/tei:TEI/@xml:id"/>
        <xsl:variable name="g-graphic" select="root()//tei:graphic[@xml:id = substring-after(current()/@facs,'#')]"/>
        <xsl:variable name="snippet-relpath" select="$g-graphic/@url"/>
        <xsl:variable name="surface-id" select="$g-graphic/ancestor::tei:surface/tei:graphic/@url"/>
        <span class="gThumbnail">
            <a>
                <xsl:choose>
                    <xsl:when test="$makeAnnotateLink = 'true'">
                        <xsl:attribute name="href">annotate.xql?t={$tablet-id}&amp;s={encode-for-uri($surface-id)}&amp;a={$annotation-id}</xsl:attribute>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:attribute name="href">#</xsl:attribute>
                    </xsl:otherwise>
                </xsl:choose>
                <img src="$tablets-root/{$tablet-id}/{$snippet-relpath}"/>
                <span class="attributes">
                    <table>
                        <tbody>
                            <tr>
                                <td>ID</td>
                                <td>
                                    <xsl:value-of select="@xml:id"/>
                                </td>
                            </tr>
                            <tr>
                                <td>Sign</td>
                                <td>
                                    <xsl:value-of select="@type"/>
                                </td>
                            </tr>
                            <tr>
                                <td>Reading</td>
                                <td>
                                    <xsl:value-of select="if (matches(text(),'^\p{Lu}+$')) then text() else lower-case(text())"/>
                                </td>
                            </tr>
                            <tr>
                                <td>Context</td>
                                <td>
                                    <xsl:value-of select="parent::tei:seg"/>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </span>
            </a>
        </span>
    </xsl:template>



</xsl:stylesheet>