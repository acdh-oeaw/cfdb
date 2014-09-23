<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.tei-c.org/ns/1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" exclude-result-prefixes="xs xd tei" version="2.0">
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Aug 21, 2014</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> Daniel Schopper</xd:p>
            <xd:p>Seeds a TEI template for the Image Markup Tool format with data of a given image.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:output method="xml" encoding="UTF-8" indent="yes"/>
    <xd:doc scope="component">
        <xd:desc>the filename of the image</xd:desc>
    </xd:doc>
    <xsl:param name="filename"/>
	
	<xd:doc scope="component">
		<xd:desc>the id of the tablet the image belongs to</xd:desc>
	</xd:doc>
	<xsl:param name="tablet-id"/>
	
	<xd:doc scope="component">
        <xd:desc>the title of the Image Markup Tool Document</xd:desc>
    </xd:doc>
    <xsl:param name="title"/>
	
    <xd:doc scope="component">
        <xd:desc>the height of the image to mark up</xd:desc>
    </xd:doc>
    <xsl:param name="height"/>
    <xd:doc scope="component">
        <xd:desc>the width of the image to mark up</xd:desc>
    </xd:doc>
    <xsl:param name="width"/>
    
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="/tei:TEI">
       <xsl:copy>
<!--           <xsl:attribute name="xml:id" select="translate($title,' ','')"/>-->
       	<xsl:attribute name="xml:id" select="concat(replace($tablet-id,'^tablet','surface'),'_',translate($title,' ',''))"/>
           <xsl:copy-of select="@* except @xml:id"/>
           <xsl:apply-templates/>
       </xsl:copy>
    </xsl:template>
	
	<xsl:template match="/tei:TEI/tei:text/@type[. = 'tablet']">
		<xsl:attribute name="type">surface</xsl:attribute>
	</xsl:template>
	
    <xsl:template match="/tei:TEI/tei:teiHeader[1]/tei:revisionDesc/tei:listChange[1]">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <change when="{current-dateTime()}" status="draft">automatically created after <xsl:value-of select="$filename"/>
            </change>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="/tei:TEI/tei:teiHeader[1]/tei:fileDesc[1]/tei:titleStmt[1]/tei:title[1]">
        <xsl:copy>
            <xsl:value-of select="$title"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="/tei:TEI/tei:facsimile[1]/tei:surface[1]/tei:graphic[1]">
        <xsl:copy>
            <xsl:attribute name="width" select="$width"/>
            <xsl:attribute name="height" select="$height"/>
            <xsl:attribute name="url" select="$filename"/>
            <xsl:copy-of select="@* except (@width,@height,@url)"/>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>