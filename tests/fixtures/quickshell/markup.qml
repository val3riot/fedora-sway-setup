import QtQuick
import Quickshell
import "notifications/Markup.js" as Markup
ShellRoot {
    function check(input, expected) {
        const actual = Markup.normalize(input);
        if (actual !== expected) { console.error("TEST FAILED markup", JSON.stringify(input), actual, expected); Qt.exit(1); }
    }
    Timer { interval: 20; running: true; onTriggered: {
        check("Plain & text", "Plain &amp; text");
        check("<b>bold</b> <i>italic</i> <u>under</u>", "<b>bold</b> <i>italic</i> <u>under</u>");
        check("<h1>Bluetooth</h1>Premi <b>123456</b>", "<b>Bluetooth</b><br>Premi <b>123456</b>");
        check("&amp; &lt; &gt; &quot; &apos; &#65; &#x41;", "&amp; &lt; &gt; \" ' A A");
        check("&lt;b&gt;literal&lt;/b&gt;", "&lt;b&gt;literal&lt;/b&gt;");
        check("&amp;lt;", "&amp;lt;");
        check("<b><i>broken</b> tail</i>", "<b><i>broken</i></b> tail");
        check("<b style='color:red' onclick='bad()'>safe</b>", "<b>safe</b>");
        check("<a href='anything'>label</a><img src='anything' alt='description'>", "labeldescription");
        check("<script>dangerous()</script><style>bad</style>text", "text");
        check("line1\nline2\r\nline3", "line1<br>line2<br>line3");
        check("<div>one</div><p>two</p>", "one<br>two");
        check("2 < 3 > 1", "2 &lt; 3 &gt; 1");
        check("<b>unclosed", "<b>unclosed</b>");
        check("text<b", "text");
        check("<unknown>content</unknown>", "content");
        check("<b data-x='>evil'>good</b>", "<b>good</b>");
        check("&#x110000; &#0;", "\ufffd \ufffd");
        console.warn("TEST markup OK 18 checks");
        Qt.quit();
    }
    }
}
