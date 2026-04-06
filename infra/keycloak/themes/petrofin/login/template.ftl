<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<html class="${properties.kcHtmlClass!}" lang="${(locale.currentLanguageTag)!'en'}">
<head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta name="robots" content="noindex, nofollow">
    <#if properties.meta?has_content>
        <#list properties.meta?split(' ') as metaItem>
            <#assign metaParts = metaItem?split('==')>
            <#if metaParts?size == 2>
                <meta name="${metaParts[0]}" content="${metaParts[1]}"/>
            </#if>
        </#list>
    </#if>
    <title>${msg("loginTitle",(realm.displayName!''))}</title>
    <#if properties.stylesCommon?has_content>
        <#list properties.stylesCommon?split(' ') as style>
            <link href="${url.resourcesCommonPath}/${style}" rel="stylesheet" />
        </#list>
    </#if>
    <#if properties.styles?has_content>
        <#list properties.styles?split(' ') as style>
            <link href="${url.resourcesPath}/${style}" rel="stylesheet" />
        </#list>
    </#if>
    <#if properties.scripts?has_content>
        <#list properties.scripts?split(' ') as script>
            <script src="${url.resourcesPath}/${script}" type="text/javascript"></script>
        </#list>
    </#if>
</head>
<body class="${properties.kcLoginClass!} ${bodyClass!}">
    <div id="kc-header">
        <div id="kc-header-wrapper">
            <#nested "header">
        </div>
    </div>

    <div id="kc-content">
        <#if realm.internationalizationEnabled?? && realm.internationalizationEnabled && locale?? && locale.supported?? && (locale.supported?size > 1)>
            <div id="kc-locale">
                <label for="kc-locale-select" class="${properties.kcSrOnlyClass!}">${msg("languages")}</label>
                <select id="kc-locale-select" onchange="if (this.value) window.location.href = this.value;">
                    <#list locale.supported as language>
                        <option value="${language.url}" <#if language.current?? && language.current>selected</#if>>
                            ${language.label}
                        </option>
                    </#list>
                </select>
            </div>
        </#if>

        <#if displayMessage && message?has_content && (message.type != "warning" || !(isAppInitiatedAction?? && isAppInitiatedAction))>
            <div id="kc-alert-wrapper" class="${properties.kcFeedbackAreaClass!}">
                <div class="${properties.kcAlertClass!} pf-m-${message.type!}">
                    <div class="${properties.kcAlertTitleClass!}">${kcSanitize(message.summary)?no_esc}</div>
                </div>
            </div>
        </#if>

        <div id="kc-content-wrapper">
            <div id="kc-form-wrapper">
                <#if displayRequiredFields>
                    <div class="subtitle"><span class="required">*</span> ${msg("requiredFields")}</div>
                </#if>

                <#if auth?has_content && auth.showUsername()>
                    <#nested "show-username">
                    <div id="kc-username" class="${properties.kcFormGroupClass!}">
                        <label class="${properties.kcLabelClass!}">${msg("username")}</label>
                        <div id="kc-attempted-username">${auth.attemptedUsername}</div>
                        <#if auth.showResetCredentials()>
                            <a id="reset-login" href="${url.loginRestartFlowUrl}" aria-label="${msg("restartLoginTooltip")}">
                                <span class="kc-tooltip-text">${msg("restartLoginTooltip")}</span>
                            </a>
                        </#if>
                    </div>
                </#if>

                <h1 id="kc-page-title"><#nested "header"></h1>

                <div id="kc-form">
                    <#nested "form">
                </div>

                <div id="kc-social-providers">
                    <#nested "socialProviders">
                </div>

                <#if auth?has_content && auth.showTryAnotherWayLink()>
                    <div id="kc-try-another-way">
                        <form id="kc-select-try-another-way-form" action="${url.loginAction}" method="post">
                            <input type="hidden" name="tryAnotherWay" value="on"/>
                            <a href="#" id="try-another-way" onclick="document.forms['kc-select-try-another-way-form'].requestSubmit(); return false;">
                                ${msg("doTryAnotherWay")}
                            </a>
                        </form>
                    </div>
                </#if>
            </div>

            <#if displayInfo>
                <div id="kc-info-wrapper">
                    <#nested "info">
                </div>
            </#if>
        </div>
    </div>

    <#nested "scripts">
</body>
</html>
</#macro>
