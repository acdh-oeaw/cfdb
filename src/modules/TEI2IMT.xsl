<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.tei-c.org/ns/1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xs xd tei" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Aug 21, 2014</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> aac</xd:p>
            <xd:p>inserts changes made to the TEI seg and g-elements into the IMT annotation div</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tei:div[@xml:id='imtImageAnnotations']/tei:div[@type='imtAnnotation']">
        <xsl:variable name="corresp" select="@corresp"/>
        <xsl:variable name="glyph" select="root()//tei:g[@facs=$corresp]"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <head>
                <xsl:value-of select="$glyph/@type"/>
            </head>
            <div>
                <p>
                    <xsl:attribute name="xml:space">preserve</xsl:attribute>
                    <xsl:text>
</xsl:text>
                    <xsl:value-of select="concat('line:     ',$glyph/ancestor::tei:line/@n,'&#xA;')"/>
                    <xsl:value-of select="concat('reading:  ',$glyph,'&#xA;')"/>
                    <xsl:value-of select="concat('context:  ',$glyph/parent::tei:seg[@type='context'],'&#xA;')"/>
                    <xsl:value-of select="concat('sequence: ',$glyph/@rend,'&#xA;')"/>
                    <xsl:value-of select="concat('note:     ',$glyph/parent::tei:seg[@type='context']/following-sibling::*[1][self::tei:note],'&#xA;')"/>
                </p>
            </div>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>