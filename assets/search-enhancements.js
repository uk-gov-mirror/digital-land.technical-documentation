(function () {
  const originalDefine = customElements.define.bind(customElements);

  function escapeHtml(value) {
    return String(value).replace(/[&<>"']/g, function (char) {
      return {
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
      }[char];
    });
  }

  function escapeRegExp(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  function termsFromQuery(query) {
    return String(query)
      .trim()
      .replace(/"/g, " ")
      .toLowerCase()
      .split(/\s+/)
      .filter(Boolean);
  }

  function parseSearchQuery(query) {
    const phrases = [];
    const remaining = String(query).replace(/"([^"]+)"/g, function (match, phrase) {
      const normalizedPhrase = phrase.trim();

      if (normalizedPhrase) {
        phrases.push(normalizedPhrase.toLowerCase());
      }

      return " ";
    });

    const terms = termsFromQuery(remaining);

    if (!phrases.length && !terms.length) {
      return {
        phrases: [],
        terms: termsFromQuery(query),
      };
    }

    return {
      phrases: phrases,
      terms: terms,
    };
  }

  function highlightTermsFromQuery(query) {
    const parsedQuery = parseSearchQuery(query);

    return parsedQuery.phrases.concat(parsedQuery.terms);
  }

  function normalizedQueryForSnippet(query) {
    const parsedQuery = parseSearchQuery(query);

    return parsedQuery.phrases[0] || parsedQuery.terms.join(" ");
  }

  function headingsForItem(item) {
    if (Array.isArray(item.headings)) {
      return item.headings;
    }

    return String(item.headings || "")
      .split(/\s{2,}/)
      .map(function (heading) {
        return heading.trim();
      })
      .filter(Boolean);
  }

  function headingsText(item) {
    return headingsForItem(item).join(" ");
  }

  function findMatchedHeading(item, query) {
    const parsedQuery = parseSearchQuery(query);
    const matchTerms = parsedQuery.phrases.concat(parsedQuery.terms);

    if (!matchTerms.length) {
      return "";
    }

    return headingsForItem(item).find(function (heading) {
      const lowerHeading = heading.toLowerCase();

      return matchTerms.every(function (term) {
        return lowerHeading.includes(term);
      });
    }) || "";
  }

  function findMatch(content, query) {
    const normalizedQuery = normalizedQueryForSnippet(query);
    const lowerContent = content.toLowerCase();
    const phraseIndex = lowerContent.indexOf(normalizedQuery.toLowerCase());

    if (phraseIndex >= 0) {
      return {
        index: phraseIndex,
        text: content.slice(phraseIndex, phraseIndex + normalizedQuery.length),
      };
    }

    return termsFromQuery(query)
      .map(function (term) {
        const index = lowerContent.indexOf(term);

        return {
          index: index,
          text: index >= 0 ? content.slice(index, index + term.length) : term,
        };
      })
      .filter(function (match) {
        return match.index >= 0;
      })
      .sort(function (a, b) {
        return a.index - b.index;
      })[0];
  }

  function createSnippet(content, query) {
    const match = findMatch(content, query);
    const start = match ? Math.max(0, match.index - 70) : 0;
    const end = match ? Math.min(content.length, match.index + 150) : 180;
    const snippet = content.slice(start, end).trim();

    return {
      text: (start > 0 ? "... " : "") + snippet + (end < content.length ? " ..." : ""),
      matchedText: match ? match.text : "",
    };
  }

  function highlightSnippet(snippet, query) {
    const normalizedQuery = normalizedQueryForSnippet(query);
    const escapedSnippet = escapeHtml(snippet);

    if (normalizedQuery && snippet.toLowerCase().includes(normalizedQuery.toLowerCase())) {
      const phraseRegex = new RegExp("(" + escapeRegExp(normalizedQuery) + ")", "gi");
      return escapedSnippet.replace(phraseRegex, "<mark>$1</mark>");
    }

    const terms = highlightTermsFromQuery(query).map(escapeRegExp);

    if (!terms.length) {
      return escapedSnippet;
    }

    const regex = new RegExp("(" + terms.join("|") + ")", "gi");
    return escapedSnippet.replace(regex, "<mark>$1</mark>");
  }

  function withTextFragment(url, matchedText) {
    if (!matchedText) {
      return url;
    }

    return url + "#:~:text=" + encodeURIComponent(matchedText.trim());
  }

  function scoreResult(item, query, parsedQuery) {
    const title = String(item.title || "").toLowerCase();
    const headings = headingsText(item).toLowerCase();
    const content = String(item.content || item.templateContent || "").toLowerCase();
    const normalizedQuery = normalizedQueryForSnippet(query);
    let score = 0;

    if (normalizedQuery && title.includes(normalizedQuery)) {
      score += 100;
    }

    if (normalizedQuery && headings.includes(normalizedQuery)) {
      score += 120;
    }

    if (normalizedQuery && content.includes(normalizedQuery)) {
      score += 80;
    }

    parsedQuery.phrases.forEach(function (phrase) {
      if (title.includes(phrase)) {
        score += 80;
      }

      if (headings.includes(phrase)) {
        score += 100;
      }

      if (content.includes(phrase)) {
        score += 60;
      }
    });

    parsedQuery.terms.forEach(function (term) {
      if (title.includes(term)) {
        score += 10;
      }

      if (headings.includes(term)) {
        score += 8;
      }

      if (content.includes(term)) {
        score += 2;
      }
    });

    return score;
  }

  function enhanceSiteSearchElement(SiteSearchElement) {
    return class EnhancedSiteSearchElement extends SiteSearchElement {
      findResults(searchQuery, searchIndex) {
        const parsedQuery = parseSearchQuery(searchQuery);
        const matchTerms = parsedQuery.phrases.concat(parsedQuery.terms);

        if (!matchTerms.length) {
          return [];
        }

        return searchIndex
          .map(function (item, index) {
            const title = String(item.title || "").toLowerCase();
            const headings = headingsText(item).toLowerCase();
            const content = String(item.content || item.templateContent || "").toLowerCase();
            const matched = matchTerms.every(function (term) {
              return title.includes(term) || headings.includes(term) || content.includes(term);
            });

            if (!matched) {
              return null;
            }

            return Object.assign({}, item, {
              searchScore: scoreResult(item, searchQuery, parsedQuery),
              searchIndexOrder: index,
            });
          })
          .filter(Boolean)
          .sort(function (a, b) {
            return b.searchScore - a.searchScore || a.searchIndexOrder - b.searchIndexOrder;
          });
      }

      renderResults(query, populateResults) {
        this.currentSearchQuery = query;

        if (!this.searchIndex) {
          return populateResults(this.searchResults);
        }

        this.searchResults = this.findResults(query, this.searchIndex).map(function (item) {
          const matchedHeading = findMatchedHeading(item, query);
          const snippet = createSnippet(String(item.content || ""), query);
          const matchedText = matchedHeading || snippet.matchedText;

          return Object.assign({}, item, {
            searchHeading: matchedHeading,
            searchTitleHtml: highlightSnippet(matchedHeading || item.title, query),
            searchSnippet: snippet.text,
            searchSnippetHtml: highlightSnippet(snippet.text, query),
            url: withTextFragment(item.url, matchedText),
          });
        });

        populateResults(this.searchResults);
      }

      handleOnConfirm(result) {
        if (!result || !result.url) {
          return;
        }

        window.location.href = result.url;
      }

      inputValueTemplate(result) {
        if (result) {
          return result.searchHeading || result.title;
        }
      }

      resultTemplate(result) {
        if (!result) {
          return;
        }

        const section = result.hasFrontmatterDate && result.section
          ? escapeHtml(result.section) + "<br>" + escapeHtml(result.date)
          : escapeHtml(result.section || result.date || "");
        const resultTitle = result.searchHeading || result.title;
        const pageContext = result.searchHeading && result.searchHeading !== result.title
          ? escapeHtml(result.title) + (section ? "<br>" + section : "")
          : section;

        return [
          '<span class="app-site-search__result-title">' + (result.searchTitleHtml || escapeHtml(resultTitle)) + "</span>",
          pageContext
            ? '<span class="app-site-search--section">' + pageContext + "</span>"
            : "",
          result.searchSnippet
            ? '<span class="app-site-search__result-snippet">' + result.searchSnippetHtml + "</span>"
            : "",
        ].join("");
      }
    };
  }

  customElements.define = function (name, constructor, options) {
    if (name === "site-search") {
      return originalDefine(name, enhanceSiteSearchElement(constructor), options);
    }

    return originalDefine(name, constructor, options);
  };
})();
