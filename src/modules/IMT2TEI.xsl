<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.tei-c.org/ns/1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="#all" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Aug 21, 2014</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> aac</xd:p>
            <xd:p>Transforms the output of the image markup tool into TEI sourceDoc / seg / g-construct. This process is unobstrusive: while the information present to the Image Markup Tool lives in tei:text/tei:body/tei:div elements, the 'final' data lives under tei:sourceDoc/tei:surface/tei:line ... </xd:p>
        </xd:desc>
    </xd:doc>

    <xsl:output indent="yes"/>

    <xsl:variable name="tablet-id" select="/tei:TEI/@xml:id"/>
    
    

    <xsl:template match="/">
        <!-- first recreate xml:ids for glyphs/annotations -->
        <xsl:variable as="element(tei:TEI)" name="IMTidsReset">
            <xsl:apply-templates mode="resetIMTids" select="tei:TEI"/>
        </xsl:variable>
        <xsl:variable as="element(tei:TEI)" name="imt2tei">
            <xsl:apply-templates select="$IMTidsReset"/>
        </xsl:variable>
        <xsl:apply-templates select="$imt2tei" mode="rmNsPrefixes"/>
    </xsl:template>

    <xsl:template match="node() | @*" mode="#all">
        <xsl:copy>
            <xsl:apply-templates mode="#current" select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="*" mode="rmNsPrefixes" priority="1">
        <xsl:element name="{local-name(.)}" namespace="{namespace-uri(.)}">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:element>
    </xsl:template>
    

    <xd:doc>
        <xd:desc>IMT gives automatic ids to the annotated zones starting with 'imtArea', e.g. "imtArea_0";
            however, we want the tei:g/@xml:ids to be stable over time (i.e. inserting another annotation / glyph) should 
            not affect the ids of the existing ones; and to be unique in the database context - so we overwrite the 
            automatic IMT ids with our own (random) ids</xd:desc>
    </xd:doc>
    <xsl:template match="tei:zone/@xml:id[starts-with(.,'imtArea')]" mode="resetIMTids">
        <xsl:attribute name="xml:id" select="concat('zone_',$tablet-id,'_',generate-id(.))"/>
    </xsl:template>
    <xsl:template match="tei:div[@type='imtAnnotation']/@corresp[starts-with(.,'#imtArea')]" mode="resetIMTids">
        <xsl:variable name="zone-id" select="substring-after(.,'#')"/>
        <xsl:attribute name="corresp" select="concat('#zone_',$tablet-id,'_',generate-id(ancestor::tei:TEI//tei:zone[@xml:id = $zone-id]/@xml:id))"/>
    </xsl:template>

    <xd:doc>
        <xd:desc>This stylesheet is to be applied whenever a new tablet is saved (i.e. tei:sourceDoc gets inserted) 
            and when a tablet is updated (i.e. tei:sourceDoc is already present)</xd:desc>
    </xd:doc>
    <xsl:template match="tei:TEI[not(tei:sourceDoc)]">
        <xsl:variable as="item()*" name="contexts">
            <xsl:for-each select="tei:text/tei:body/tei:div[@xml:id='imtImageAnnotations']/tei:div[@type='imtAnnotation']">
                <context xmlns="">
                    <sign>
                        <xsl:value-of select="normalize-space(tei:head)"/>
                    </sign>
                    <facs>
                        <xsl:value-of select="@corresp"/>
                    </facs>
                    <xsl:for-each select="tokenize(tei:div/tei:p,'\s*\n\s*')">
                        <xsl:variable name="field" select="normalize-space(substring-before(.,':'))"/>
                        <xsl:variable name="value" select="normalize-space(substring-after(.,':'))"/>
                        <xsl:if test="$field!=''">
                            <xsl:element name="{$field}">
                                <xsl:value-of select="$value"/>
                            </xsl:element>
                        </xsl:if>
                    </xsl:for-each>
                </context>
            </xsl:for-each>
        </xsl:variable>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates select="tei:teiHeader">
                <xsl:with-param name="contexts" select="$contexts" tunnel="yes"/>
            </xsl:apply-templates>
            <xsl:copy-of select="node() except (tei:teiHeader,tei:text)"/>
            <sourceDoc>
                <surface>
                    <xsl:for-each-group group-by="line" select="$contexts">
                        <line n="{current-grouping-key()}">
                            <xsl:for-each select="current-group()">
                                <xsl:variable name="sign" select="sign"/>
                                <xsl:variable name="facs" select="facs"/>
                                <xsl:variable name="reading" select="reading"/>
                                <xsl:variable name="sequence" select="sequence"/>
                                <xsl:variable name="arrangement" select="arrangement"/>
                                <xsl:variable name="id" select="replace($facs,'^#zone','g')"/>

                                <seg type="context">
                                    <xsl:analyze-string regex="{reading}" select="context">
                                        <xsl:matching-substring>
                                            <g facs="{replace($facs,'^#zone',concat('_glyphs/',$tablet-id,'/g'))}" corresp="{$facs}" type="{$sign}">
                                                <xsl:attribute name="xml:id" select="$id"/>
                                                <xsl:if test="$sequence!='' or $arrangement!=''">
                                                    <xsl:attribute name="ref" select="concat('#',replace($facs,'^#zone','charDecl'))"/>
                                                </xsl:if>
                                                <xsl:value-of select="$reading"/>
                                            </g>
                                        </xsl:matching-substring>
                                        <xsl:non-matching-substring>
                                            <xsl:value-of select="."/>
                                        </xsl:non-matching-substring>
                                    </xsl:analyze-string>
                                    <note>
                                        <xsl:value-of select="normalize-space(note)"/>
                                    </note>
                                </seg>
                                <gap/>
                            </xsl:for-each>
                        </line>
                    </xsl:for-each-group>
                </surface>
            </sourceDoc>
            <xsl:copy-of select="tei:text"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="tei:encodingDesc">
        <xsl:param name="contexts" as="element(context)*" tunnel="yes"/>
        <xsl:copy>
            <xsl:copy-of select="@*|node() except tei:charDecl"/>
            <charDecl>
                <xsl:for-each select="$contexts[sequence or arrangement]">
                    <xsl:variable name="id" select="replace(facs,'^#zone','charDecl')"/>
                    <glyph>
                        <xsl:attribute name="xml:id" select="$id"/>
                        <xsl:if test="sequence">
                            <charProp>
                                <localName>sequence</localName>
                                <value>
                                    <xsl:value-of select="sequence"/>
                                </value>
                            </charProp>
                        </xsl:if>
                        <xsl:if test="arrangement">
                            <charProp>
                                <localName>arrangement</localName>
                                <value>
                                    <xsl:value-of select="arrange"/>
                                </value>
                            </charProp>
                        </xsl:if>
                    </glyph>
                </xsl:for-each>
            </charDecl>
        </xsl:copy>
    </xsl:template>


</xsl:stylesheet>