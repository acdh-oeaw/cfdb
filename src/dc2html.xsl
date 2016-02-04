<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:dc="http://purl.org/dc/elements/1.1/" exclude-result-prefixes="#all" version="2.0">
    <xsl:template match="/*" priority="1">
        <div class="archive-md"> 
            <h4>Metadata record for <i>
                    <xsl:value-of select="dc:title"/>
                </i>
            </h4>
            <table>
                <tbody>
                <xsl:apply-templates/>
                </tbody>
            </table>
        </div>
    </xsl:template>
    <xsl:template match="dc:*|dcterms:*">
        <tr>
            <td>
                <xsl:value-of select="concat(upper-case(substring(local-name(),1,1)), substring(local-name(),2))" xml:space="preserve"/>
            </td>
            <td data-md-cat="{local-name()}">
                <xsl:value-of select="."/>
            </td>
        </tr>
    </xsl:template>
    
    <xsl:template match="*[local-name() = 'extra']"/>
        
    
</xsl:stylesheet>