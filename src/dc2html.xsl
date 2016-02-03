<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cfdb="http://www.oeaw.ac.at/acdh/cfdb0.9/db" xmlns:dc="http://purl.org/dc/elements/1.1/" exclude-result-prefixes="xs" version="2.0">
    <xsl:template match="/cfdb:archive">
        <table class="archive-md">
            <tbody>
            <xsl:apply-templates/>
        </tbody>
        </table>
    </xsl:template>
    <xsl:template match="dc:*|dcterms:*">
        <tr>
            <td>
                <xsl:value-of select="concat(upper-case(substring(local-name(),1,1)), substring(local-name(),2))" xml:space="preserve"/>
            </td>
            <td>
                <xsl:value-of select="."/>
            </td>
        </tr>
    </xsl:template>
</xsl:stylesheet>